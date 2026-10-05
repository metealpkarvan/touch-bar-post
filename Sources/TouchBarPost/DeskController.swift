import AppKit
import PostCore

extension NSTouchBarItem.Identifier {
    static let postScenes = Self("com.metealpkarvan.TouchBarPost.scenes")
    static let postRail = Self("com.metealpkarvan.TouchBarPost.rail")
    static let postQuick = Self("com.metealpkarvan.TouchBarPost.quick")
    static let postPrivacy = Self("com.metealpkarvan.TouchBarPost.privacy")
    static func scene(_ value: Scene) -> Self { Self("com.metealpkarvan.TouchBarPost.scene." + value.rawValue) }
}

final class CardButton: NSButton {
    var card: Card!
    var selectedCard = false
    var language: Language = .tr
    var now = Date()
    override func draw(_ rect: NSRect) {
        (selectedCard ? card.ink.color.withAlphaComponent(0.12) : NSColor.postBackground.withAlphaComponent(0.65)).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 2), xRadius: 9, yRadius: 9).fill()
        if selectedCard { card.ink.color.setStroke(); NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 2), xRadius: 9, yRadius: 9).stroke() }
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [.font:NSFont.systemFont(ofSize:13,weight:.semibold), .foregroundColor:NSColor.postWhite, .paragraphStyle:paragraph]
        (card.kind.mark + "  " + card.title as NSString).draw(in: NSRect(x:12,y:31,width:bounds.width-24,height:21), withAttributes:attributes)
        let summary = card.isDue(at:now) ? tr(language,"Vakti geldi", "Ready now") : card.kind.name(language)
        let date = card.dueAt.map { " · " + DateFormatter.localizedString(from:$0,dateStyle:.short,timeStyle:.short) } ?? ""
        ((card.pinned ? "• " : "") + summary + date as NSString).draw(in:NSRect(x:12,y:10,width:bounds.width-24,height:17),withAttributes:[.font:NSFont.systemFont(ofSize:10),.foregroundColor:card.ink.color,.paragraphStyle:paragraph])
    }
}

final class DeskController: NSWindowController, NSTouchBarDelegate, NSWindowDelegate {
    private(set) var archive: Archive
    private let store: ArchiveStore?
    private let notifications: NotificationDesk?
    private var blocked = false
    private var activeID: UUID?
    private var editingID: UUID?
    private var lastDueID: UUID?
    private var lastQueue: [Card] = []
    private var lastDueSet: Set<UUID> = []
    private var lastCycle = Date()
    private var hold = false
    private var tick: Timer?, animation: Timer?
    private var floating: NSPanel?
    private var floatingRail: RailView?
    private var physicalRail: RailView?
    private var scenePopover: NSPopoverTouchBarItem?
    private var privacyTouchButton: NSButton?
    private var scenes = NSSegmentedControl(), languageButton = NSButton(), holdButton = NSButton(), privacyButton = NSButton(), notificationButton = NSButton()
    private var kind = NSPopUpButton(), formScene = NSPopUpButton(), ink = NSPopUpButton(), completedFilter = NSPopUpButton()
    let titleField = NSTextField(), bodyField = NSTextView(), dueField = NSDatePicker(), pinnedField = NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let preview = RailView(frame:.zero)
    private var search = NSSearchField(), listScroll = NSScrollView()
    private var saveButton = NSButton(), finishButton = NSButton(), snoozeButton = NSButton(), deleteButton = NSButton()
    private var status = NSTextField(), editorHeading = NSTextField()
    private var statusItem: NSStatusItem?
    private var labels: [(NSTextField,String,String)] = []
    private var buttons: [(NSButton,String,String)] = []
    private var message = ""
    var now: () -> Date
    var language: Language { archive.settings.language }
    var displayed: Card? { archive.queue(at:now()).first { $0.id == activeID } }
    var hasDraftChanges: Bool {
        guard let card = archive.cards.first(where: { $0.id == editingID }) else { return !titleField.stringValue.isEmpty || !bodyField.string.isEmpty }
        return titleField.stringValue != card.title || bodyField.string != card.body ||
            kind.indexOfSelectedItem != CardKind.allCases.firstIndex(of:card.kind) ||
            formScene.indexOfSelectedItem != Scene.allCases.firstIndex(of:card.scene) ||
            ink.indexOfSelectedItem != Ink.allCases.firstIndex(of:card.ink) ||
            (pinnedField.state == .on) != card.pinned ||
            (card.kind == .reminder && abs(dueField.dateValue.timeIntervalSince(card.dueAt!)) >= 1)
    }
    func mayLeaveDraft() -> Bool { !hasDraftChanges || confirm(tr(language,"Kaydedilmemiş değişiklikler bırakılsın mı? Kaydetmek için Vazgeç’i seç.","Discard unsaved changes? Choose Cancel to save them first.")) }

    init(store: ArchiveStore? = nil, archive initial: Archive = Archive(), timers: Bool = true,
         notifications: NotificationDesk? = nil, statusItem: Bool = true, now: @escaping () -> Date = Date.init) {
        self.store = store; self.notifications = notifications; self.now = now
        archive = initial
        var loadError: String?
        if let store = store { do { archive = try store.load() } catch { loadError = error.localizedDescription; blocked = true } }
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:1040,height:660),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title = "Şerit · Touch Bar Post"; window.appearance = NSAppearance(named:.darkAqua); window.isReleasedWhenClosed = false
        super.init(window:window); window.delegate = self; buildInterface(); window.touchBar = makeTouchBar()
        for responder in [titleField as NSResponder, bodyField, dueField] { responder.touchBar = window.touchBar }
        if statusItem { self.statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength) }
        notifications?.onError = { [weak self] error in self?.message = error; self?.updateStatus() }
        notifications?.onOpen = { [weak self] id in self?.showDesk(); if let id = id { self?.selectCard(id) } }
        applyLanguage(); newDraft(); refresh(rebuild:true)
        if let error = loadError { message = tr(language,"Kayıt açılamadı. Orijinal dosya korundu. Veriler → JSON yedek ile kurtar. ","Archive could not be opened. Original retained. Use Data → JSON backup. ") + error; updateStatus() }
        if timers {
            tick = Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in self?.refresh(rebuild:false) }
            let timer = Timer(timeInterval:1.0/30,repeats:true) { [weak self] _ in
                guard let self = self, NSApp.isActive, !self.hold, self.archive.settings.motion else { return }
                self.preview.animate(delta:1.0/30); self.physicalRail?.animate(delta:1.0/30); self.floatingRail?.animate(delta:1.0/30)
            }; RunLoop.main.add(timer,forMode:.common); animation = timer
        }
        notifications?.refresh(archive); window.center()
    }
    required init?(coder:NSCoder) { fatalError("Programmatic controller") }
    deinit { tick?.invalidate(); animation?.invalidate() }

    private func text(_ a:String,_ b:String,_ frame:NSRect,size:CGFloat = 12,color:NSColor = .postMuted,in parent:NSView) -> NSTextField {
        let field = label(a,frame,size:size,color:color,in:parent); labels.append((field,a,b)); return field
    }
    private func control(_ a:String,_ b:String,_ frame:NSRect,_ action:Selector,in parent:NSView) -> NSButton {
        let result = button(a,frame,target:self,action:action,in:parent); buttons.append((result,a,b)); return result
    }
    private func buildInterface() {
        let root = Canvas(frame:NSRect(x:0,y:0,width:1040,height:660)); window?.contentView = root
        _ = text("ŞERİT / TOUCH BAR POST","ŞERİT / TOUCH BAR POST",NSRect(x:24,y:20,width:500,height:20),color:Ink.aqua.color,in:root)
        _ = text("Küçük ekran. Sana ait bir alan.","A small screen. A space of your own.",NSRect(x:22,y:48,width:990,height:46),size:32,color:.postWhite,in:root)
        _ = text("Duyurunu geçir, notunu bırak, vakti gelince hatırla.","Run an announcement, leave a note, remember at the right time.",NSRect(x:24,y:102,width:990,height:22),size:13,in:root)
        scenes = NSSegmentedControl(labels:["Masam","Mola","Ev"],trackingMode:.selectOne,target:self,action:#selector(sceneChanged(_:)))
        scenes.frame = NSRect(x:22,y:133,width:300,height:30); root.addSubview(scenes)
        holdButton = control("Akışı tut","Hold strip",NSRect(x:333,y:133,width:105,height:30),#selector(holdAction),in:root)
        privacyButton = control("Perde","Curtain",NSRect(x:443,y:133,width:105,height:30),#selector(privacyAction),in:root)
        _ = control("Masada şerit","Desk strip",NSRect(x:553,y:133,width:143,height:30),#selector(floatingAction),in:root)
        notificationButton = control("Bildirimlere izin ver","Allow notifications",NSRect(x:701,y:133,width:200,height:30),#selector(notificationsAction),in:root)
        languageButton = control("English","Türkçe",NSRect(x:915,y:133,width:101,height:30),#selector(languageAction),in:root)
        let left = Panel(frame:NSRect(x:24,y:178,width:350,height:352)); root.addSubview(left)
        search.frame = NSRect(x:14,y:16,width:191,height:27); search.target = self; search.action = #selector(filterChanged); left.addSubview(search)
        completedFilter.frame = NSRect(x:214,y:16,width:124,height:27); completedFilter.target = self; completedFilter.action = #selector(filterChanged); left.addSubview(completedFilter)
        listScroll.frame = NSRect(x:12,y:59,width:326,height:277); listScroll.hasVerticalScroller = true; listScroll.drawsBackground = false; listScroll.borderType = .noBorder; left.addSubview(listScroll)
        let right = Panel(frame:NSRect(x:394,y:178,width:622,height:352)); root.addSubview(right)
        editorHeading = text("Zarfını hazırla.","Prepare your card.",NSRect(x:18,y:15,width:583,height:25),size:18,color:.postWhite,in:right)
        for (title,english,x) in [("Tür","Kind",20),("Sahne","Scene",214),("Mürekkep","Ink",408)] {
            _ = text(title,english,NSRect(x:x,y:49,width:180,height:16),size:10,in:right)
        }
        for (pop,x) in [(kind,20),(formScene,214),(ink,408)] { pop.frame = NSRect(x:x,y:65,width:184,height:27); right.addSubview(pop) }
        kind.target = self; kind.action = #selector(kindChanged)
        _ = text("Başlık · 80 karakter","Title · 80 characters",NSRect(x:20,y:101,width:580,height:16),size:10,in:right)
        titleField.frame = NSRect(x:20,y:118,width:582,height:25); titleField.font = .systemFont(ofSize:13); right.addSubview(titleField)
        _ = text("Kısa bağlam · 400 karakter","Short context · 400 characters",NSRect(x:20,y:150,width:580,height:16),size:10,in:right)
        let bodyScroll = NSScrollView(frame:NSRect(x:20,y:168,width:582,height:68)); bodyScroll.hasVerticalScroller = true; bodyScroll.borderType = .bezelBorder
        bodyField.frame = NSRect(x:0,y:0,width:565,height:68); bodyField.isRichText = false; bodyField.font = .systemFont(ofSize:13)
        bodyField.textContainerInset = NSSize(width:6,height:6); bodyField.autoresizingMask = [.width]; bodyField.isVerticallyResizable = true
        bodyField.textContainer?.widthTracksTextView = true; bodyScroll.documentView = bodyField; right.addSubview(bodyScroll)
        _ = text("Vakti · yalnızca hatırlatma","When · reminders only",NSRect(x:20,y:245,width:260,height:16),size:10,in:right)
        dueField.frame = NSRect(x:20,y:265,width:272,height:27); dueField.datePickerStyle = .textFieldAndStepper; dueField.datePickerElements = [.yearMonthDay,.hourMinute]; right.addSubview(dueField)
        pinnedField.frame = NSRect(x:320,y:262,width:282,height:27); right.addSubview(pinnedField)
        saveButton = control("Şeride bırak","Post to strip",NSRect(x:18,y:306,width:148,height:30),#selector(saveAction),in:right); saveButton.bezelColor = Ink.aqua.color
        _ = control("Yeni","New",NSRect(x:176,y:306,width:72,height:30),#selector(newAction),in:right)
        snoozeButton = control("+5 dk","+5 min",NSRect(x:254,y:306,width:98,height:30),#selector(snoozeAction),in:right)
        finishButton = control("Tamamla","Complete",NSRect(x:358,y:306,width:136,height:30),#selector(finishAction),in:right)
        deleteButton = control("Sil","Delete",NSRect(x:500,y:306,width:102,height:30),#selector(deleteAction),in:right)
        _ = text("CANLI ŞERİT · Kartı açmak için ortasına dokun","LIVE STRIP · Tap the centre to open the card",NSRect(x:24,y:544,width:740,height:16),size:10,in:root)
        preview.frame = NSRect(x:24,y:568,width:992,height:46); wire(preview); root.addSubview(preview)
        status = text("","",NSRect(x:24,y:627,width:754,height:27),size:10,in:root)
        _ = control("Veriler / hızlı başlangıç","Data / quick start",NSRect(x:790,y:623,width:226,height:30),#selector(dataAction(_:)),in:root)
    }
    private func wire(_ view:RailView) {
        view.onPrevious = { [weak self] in self?.cycle(-1) }; view.onNext = { [weak self] in self?.cycle(1) }
        view.onOpen = { [weak self] in guard let self = self else { return }; self.showDesk(); if let id = self.displayed?.id { self.selectCard(id) } else { self.newDraft() } }
        view.onAction = { [weak self] in self?.stripAction() }
    }
    private func applyLanguage() {
        for (field,a,b) in labels { field.stringValue = tr(language,a,b) }
        for (control,a,b) in buttons { control.title = tr(language,a,b) }
        for (index,scene) in Scene.allCases.enumerated() { scenes.setLabel(scene.name(language),forSegment:index) }
        let selected = [kind.indexOfSelectedItem,formScene.indexOfSelectedItem,ink.indexOfSelectedItem,completedFilter.indexOfSelectedItem]
        for (control,items,index) in [(kind,CardKind.allCases.map { $0.name(language) },selected[0]),(formScene,Scene.allCases.map { $0.name(language) },selected[1]),(ink,Ink.allCases.map { $0.name(language) },selected[2]),(completedFilter,[tr(language,"Aktif","Active"),tr(language,"Tamamlanan","Completed")],selected[3])] {
            control.removeAllItems(); control.addItems(withTitles:items); control.selectItem(at:max(0,index))
        }
        pinnedField.title = tr(language,"Sahnenin başına sabitle","Pin to the front of this scene")
        search.placeholderString = tr(language,"Kartlarında ara","Search cards")
        languageButton.title = language == .tr ? "English" : "Türkçe"
        scenePopover?.collapsedRepresentationLabel = archive.settings.scene.name(language)
        window?.touchBar = makeTouchBar()
        for responder in [titleField as NSResponder, bodyField, dueField] { responder.touchBar = window?.touchBar }
    }
    @discardableResult private func change(_ body:(inout Archive)throws -> Void) -> Bool {
        guard !blocked else { message = tr(language,"Orijinal kayıt kilitli. Veriler menüsünden kurtar veya yedek yükle.","Original archive is protected. Recover it or import a backup from Data."); updateStatus(); return false }
        do { var candidate = archive; try body(&candidate); candidate = try candidate.validated(); try store?.save(candidate); archive = candidate
            notifications?.refresh(archive); refresh(rebuild:true); return true
        } catch { message = error.localizedDescription; updateStatus(); return false }
    }
    func refresh(rebuild:Bool) {
        let date = now(), queue = archive.queue(at:date), firstDue = queue.first(where: { $0.isDue(at:date) })?.id
        let dueSet = Set(queue.filter { $0.isDue(at:date) }.map(\.id))
        if firstDue != lastDueID, firstDue != nil { activeID = firstDue; lastCycle = date; message = "" }; lastDueID = firstDue
        if !queue.contains(where: { $0.id == activeID }) { activeID = queue.first?.id }
        if !hold && NSApp.isActive && date.timeIntervalSince(lastCycle) >= 12 && firstDue == nil { cycle(1,refresh:false); lastCycle = date }
        scenes.selectedSegment = Scene.allCases.firstIndex(of:archive.settings.scene) ?? 0
        preview.update(card:displayed,privacy:archive.settings.privacy,motion:archive.settings.motion && !hold,language:language)
        physicalRail?.update(card:displayed,privacy:archive.settings.privacy,motion:archive.settings.motion && !hold,language:language)
        floatingRail?.update(card:displayed,privacy:archive.settings.privacy,motion:archive.settings.motion && !hold,language:language)
        holdButton.title = hold ? tr(language,"Akışı sürdür","Resume strip") : tr(language,"Akışı tut","Hold strip")
        privacyButton.title = archive.settings.privacy ? tr(language,"Perdeyi aç","Open curtain") : tr(language,"Perde","Curtain")
        privacyTouchButton?.title = archive.settings.privacy ? "○" : "◉"
        notificationButton.title = archive.settings.notifications ? tr(language,"Bildirimler açık ✓","Notifications on ✓") : tr(language,"Bildirimlere izin ver","Allow notifications")
        if rebuild || queue != lastQueue || dueSet != lastDueSet { rebuildList() }; lastQueue = queue; lastDueSet = dueSet; updateStatus(); updateMenu()
    }
    private func rebuildList() {
        let query = Archive.folded(search.stringValue)
        let source = completedFilter.indexOfSelectedItem == 1 ? archive.cards.filter { $0.doneAt != nil && $0.scene == archive.settings.scene }.sorted { $0.doneAt! > $1.doneAt! } : archive.queue(at:now())
        let cards = source.filter { query.isEmpty || Archive.folded($0.title + " " + $0.body).contains(query) }
        let document = Canvas(frame:NSRect(x:0,y:0,width:308,height:max(277,cards.count*65)))
        if cards.isEmpty { _ = label(tr(language,"Bu sahne boş. Bir not bırak veya hızlı başlangıcı aç.","This scene is empty. Leave a note or open quick start."),NSRect(x:12,y:22,width:280,height:70),size:13,color:.postMuted,in:document) }
        for (index,card) in cards.enumerated() {
            let row = CardButton(frame:NSRect(x:3,y:index*65,width:302,height:62)); row.card = card; row.language = language; row.now = now()
            row.selectedCard = card.id == editingID; row.isBordered = false; row.target = self; row.action = #selector(rowAction(_:)); row.identifier = NSUserInterfaceItemIdentifier(card.id.uuidString)
            row.setAccessibilityLabel(card.kind.name(language) + ": " + card.title + (card.isDue(at:now()) ? tr(language," · Vakti geldi"," · Ready now") : "")); document.addSubview(row)
        }
        listScroll.documentView = document
    }
    func selectCard(_ id:UUID) {
        guard let card = archive.cards.first(where: { $0.id == id }) else { return }
        guard id == editingID || mayLeaveDraft() else { return }
        if card.scene != archive.settings.scene && !card.isDue(at:now()) { guard change({ $0.settings.scene = card.scene }) else { return } }
        editingID = id; if card.doneAt == nil { activeID = id; hold = true }
        titleField.stringValue = card.title; bodyField.string = card.body
        kind.selectItem(at:CardKind.allCases.firstIndex(of:card.kind)!); formScene.selectItem(at:Scene.allCases.firstIndex(of:card.scene)!); ink.selectItem(at:Ink.allCases.firstIndex(of:card.ink)!)
        dueField.dateValue = card.dueAt ?? now().addingTimeInterval(25*60); pinnedField.state = card.pinned ? .on : .off
        updateEditor(); refresh(rebuild:true)
    }
    func newDraft(kind type:CardKind = .note, title:String = "", body:String = "") {
        editingID = nil; titleField.stringValue = title; bodyField.string = body; kind.selectItem(at:CardKind.allCases.firstIndex(of:type)!)
        formScene.selectItem(at:Scene.allCases.firstIndex(of:archive.settings.scene)!); ink.selectItem(at:type == .reminder ? 0 : 1)
        pinnedField.state = .off; dueField.dateValue = now().addingTimeInterval(25*60); updateEditor(); rebuildList()
    }
    private func updateEditor() {
        let card = archive.cards.first { $0.id == editingID }
        editorHeading.stringValue = editingID == nil ? tr(language,"Zarfını hazırla.","Prepare your card.") : tr(language,"Kartını düzenle.","Edit your card.")
        dueField.isEnabled = kind.indexOfSelectedItem == 2
        deleteButton.isEnabled = card != nil; finishButton.isEnabled = card != nil
        finishButton.title = card?.doneAt == nil ? tr(language,"Tamamla","Complete") : tr(language,"Geri getir","Restore")
        snoozeButton.isEnabled = card?.kind == .reminder && card?.doneAt == nil
        saveButton.title = editingID == nil ? tr(language,"Şeride bırak","Post to strip") : tr(language,"Değişikliği kaydet","Save changes")
    }
    private func cycle(_ direction:Int,refresh shouldRefresh:Bool = true) {
        let queue = archive.queue(at:now()); guard !queue.isEmpty else { return }
        let index = queue.firstIndex { $0.id == activeID } ?? 0
        activeID = queue[(index+direction+queue.count)%queue.count].id; lastCycle = now()
        if shouldRefresh { refresh(rebuild:false) }
    }
    func stripAction() {
        guard !archive.settings.privacy, let card = displayed else { return }
        if card.kind == .reminder { if change({ try $0.finish(card.id,at:now()) }) { if editingID == card.id { updateEditor() } } }
        else { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(card.title + (card.body.isEmpty ? "" : "\n" + card.body),forType:.string); message = tr(language,"Not panoya kopyalandı.","Note copied to clipboard."); updateStatus() }
    }
    private func updateStatus() {
        if !message.isEmpty { status.stringValue = message; return }
        let count = archive.cards.filter { $0.isDue(at:now()) }.count
        status.stringValue = count > 0 ? tr(language,"\(count) hatırlatmanın vakti geldi · ✓ tamamla, +5 dk ertele.","\(count) reminders are ready · ✓ complete, +5 min postpone.") : tr(language,"Touch Bar uygulama öndeyken görünür · macOS 11+ · Veriler cihazında.","Touch Bar appears while this app is frontmost · macOS 11+ · Data stays local.")
    }
    func showDesk() { showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }
    @objc func saveAction() {
        let date = now(), old = archive.cards.first { $0.id == editingID }
        var card = Card(id:editingID ?? UUID(),kind:CardKind.allCases[kind.indexOfSelectedItem],scene:Scene.allCases[formScene.indexOfSelectedItem],ink:Ink.allCases[ink.indexOfSelectedItem],title:titleField.stringValue,body:bodyField.string,pinned:pinnedField.state == .on,now:date,dueAt:kind.indexOfSelectedItem == 2 ? dueField.dateValue : nil)
        card.createdAt = old?.createdAt ?? date; card.doneAt = old?.doneAt
        if change({ try $0.put(card) }) { editingID = card.id; message = tr(language,"Kart kaydedildi.","Card saved."); selectCard(card.id); updateStatus() }
    }
    @objc func newAction() { guard mayLeaveDraft() else { return }; newDraft(); window?.makeFirstResponder(titleField) }
    @objc private func rowAction(_ sender:CardButton) { if let id = sender.identifier.flatMap({ UUID(uuidString:$0.rawValue) }) { selectCard(id) } }
    @objc private func kindChanged() { updateEditor() }
    @objc private func filterChanged() { rebuildList() }
    @objc private func sceneChanged(_ sender:NSSegmentedControl) { chooseScene(Scene.allCases[sender.selectedSegment]) }
    func chooseScene(_ scene:Scene) { guard mayLeaveDraft() else { scenes.selectedSegment = Scene.allCases.firstIndex(of:archive.settings.scene) ?? 0; return }; if change({ $0.settings.scene = scene }) { activeID = nil; hold = false; message = ""; newDraft(); scenePopover?.dismissPopover(nil); scenePopover?.collapsedRepresentationLabel = scene.name(language); refresh(rebuild:true) } }
    @objc func privacyAction() { if change({ $0.settings.privacy.toggle() }) { message = tr(language,"Perde şerit ve yeni bildirim metnini gizler; editörünü gizlemez.","Curtain hides the strip and new notification text; the editor stays visible."); updateStatus() } }
    @objc private func holdAction() { hold.toggle(); lastCycle = now(); refresh(rebuild:false) }
    @objc private func languageAction() { if change({ $0.settings.language = language == .tr ? .en : .tr }) { message = ""; applyLanguage(); updateEditor(); refresh(rebuild:true) } }
    @objc private func snoozeAction() { guard let id = editingID, mayLeaveDraft() else { return }; if change({ try $0.snooze(id,minutes:5,at:now()) }) { selectCard(id); message = tr(language,"Beş dakika sonraya ertelendi.","Postponed for five minutes."); updateStatus() } }
    @objc private func finishAction() { guard let id = editingID, mayLeaveDraft() else { return }; let done = archive.cards.first { $0.id == id }?.doneAt != nil
        if change({ if done { try $0.restore(id,at:now()) } else { try $0.finish(id,at:now()) } }) { selectCard(id) }
    }
    @objc private func deleteAction() { guard let id = editingID, confirm(tr(language,"Bu kart silinsin mi?","Delete this card?")) else { return }; if change({ $0.remove(id) }) { newDraft() } }
    private func confirm(_ title:String) -> Bool { let alert = NSAlert(); alert.messageText = title; alert.addButton(withTitle:tr(language,"Devam et","Continue")); alert.addButton(withTitle:tr(language,"Vazgeç","Cancel")); return alert.runModal() == .alertFirstButtonReturn }
    @objc private func notificationsAction() {
        guard let notifications = notifications else { message = tr(language,"Bildirimler paketlenmiş .app üzerinden kullanılabilir.","Notifications require the packaged .app."); updateStatus(); return }
        if archive.settings.notifications { _ = change { $0.settings.notifications = false }; return }
        notifications.authorize { [weak self] allowed,error in guard let self = self else { return }
            if allowed { _ = self.change { $0.settings.notifications = true } }
            else { self.message = error ?? tr(self.language,"İzin verilmedi. Sistem Ayarları → Bildirimler → Şerit bölümünden açabilirsin.","Not allowed. Enable Şerit in System Settings → Notifications."); self.updateStatus() }
        }
    }
    @objc private func floatingAction() {
        if let panel = floating { if panel.isVisible { panel.orderOut(nil) } else { panel.orderFront(nil) }; return }
        let panel = NSPanel(contentRect:NSRect(x:0,y:0,width:720,height:74),styleMask:[.titled,.utilityWindow,.nonactivatingPanel,.closable],backing:.buffered,defer:false)
        panel.title = "Şerit"; panel.level = .floating; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named:.darkAqua)
        let root = Canvas(frame:NSRect(x:0,y:0,width:720,height:74)), rail = RailView(frame:NSRect(x:10,y:13,width:700,height:48))
        wire(rail); root.addSubview(rail); panel.contentView = root; floating = panel; floatingRail = rail
        panel.center(); panel.orderFront(nil); refresh(rebuild:false)
    }
    private func menuEntry(_ title:String,_ action:Selector,menu:NSMenu,id:String? = nil) {
        let item = NSMenuItem(title:title,action:action,keyEquivalent:""); item.target = self; item.representedObject = id; menu.addItem(item)
    }
    private func updateMenu() {
        guard let statusItem = statusItem else { return }
        let due = archive.cards.filter { $0.isDue(at:now()) }.count
        statusItem.button?.title = due > 0 ? "✎ \(due)" : "✎"; statusItem.button?.setAccessibilityLabel("Şerit")
        let menu = NSMenu(); menuEntry(tr(language,"Şerit’i aç","Open Şerit"),#selector(showAction),menu:menu)
        menuEntry(tr(language,"Hızlı not","Quick note"),#selector(quickAction),menu:menu)
        menu.addItem(.separator())
        for card in archive.cards.filter({ $0.kind == .reminder && $0.doneAt == nil }).sorted(by:Archive.dueOrder).prefix(5) {
            let title = archive.settings.privacy ? tr(language,"Hatırlatma","Reminder") : card.title
            let date = card.isDue(at:now()) ? tr(language,"Vakti geldi","Ready") : DateFormatter.localizedString(from:card.dueAt!,dateStyle:.none,timeStyle:.short)
            menuEntry(title + " · " + date,#selector(openCardMenu(_:)),menu:menu,id:card.id.uuidString)
        }
        menu.addItem(.separator()); menuEntry(tr(language,"Perdeyi aç / kapat","Toggle curtain"),#selector(privacyAction),menu:menu)
        menuEntry(tr(language,"Şerit’ten çık","Quit Şerit"),#selector(NSApplication.terminate(_:)),menu:menu); menu.items.last?.target = NSApp
        statusItem.menu = menu
    }
    @objc func showAction() { showDesk() }
    @objc func quickAction() { showDesk(); guard mayLeaveDraft() else { return }; newDraft(); window?.makeFirstResponder(titleField) }
    @objc private func openCardMenu(_ sender:NSMenuItem) { showDesk(); if let value = sender.representedObject as? String, let id = UUID(uuidString:value) { selectCard(id) } }

    @objc private func dataAction(_ sender:NSButton) {
        let menu = NSMenu()
        for (title,action) in [(tr(language,"JSON yedek indir / orijinali kurtar","Export JSON / recover original"),#selector(exportAction)),(tr(language,"Yedek yükle","Import backup"),#selector(importAction)),(tr(language,"Markdown indir","Export Markdown"),#selector(markdownAction)),(tr(language,"Kayıt klasörünü aç","Open data folder"),#selector(folderAction)),(tr(language,"Örnek kartlar ekle","Add sample cards"),#selector(sampleAction)),(tr(language,"25 dakikalık mola hatırlatması","25-minute break reminder"),#selector(breakAction)),(tr(language,"Hareketi aç / kapat","Toggle motion"),#selector(motionAction)),(tr(language,"Tüm kayıtları sıfırla","Reset all records"),#selector(resetAction))] { menuEntry(title,action,menu:menu) }
        menu.popUp(positioning:nil,at:NSPoint(x:0,y:sender.bounds.height),in:sender)
    }
    private func saveFile(_ data:Data,name:String) throws {
        let panel = NSSavePanel(); panel.nameFieldStringValue = name
        if panel.runModal() == .OK, let url = panel.url { try data.write(to:url,options:.atomic) }
    }
    @objc private func exportAction() { do { try saveFile(blocked ? Data(contentsOf:store!.file) : archive.encoded(),name:blocked ? "serit-original.json" : "serit-backup.json") } catch { message = error.localizedDescription; updateStatus() } }
    @objc private func markdownAction() { do { try saveFile(Data(archive.markdown().utf8),name:"serit-notes.md") } catch { message = error.localizedDescription; updateStatus() } }
    @objc private func importAction() {
        let panel = NSOpenPanel(); panel.allowedFileTypes = ["json"]; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
            guard size <= 1_048_576 else { throw PostError.invalid("Maximum 1 MB / En fazla 1 MB.") }
            var incoming = try Archive.decode(Data(contentsOf:url)); incoming.settings.notifications = false
            guard confirm(tr(language,"Yedek mevcut kayıtları değiştirsin mi? Orijinalin kurtarma kopyası kayıt klasöründe saklanacak.","Replace records with this backup? A recovery copy of the original will stay in the data folder.")) else { return }
            try replace(incoming); message = tr(language,"Yedek yüklendi. Bildirimleri istersen yeniden aç.","Backup loaded. Enable notifications again if needed."); updateStatus()
        } catch { message = error.localizedDescription; updateStatus() }
    }
    private func replace(_ incoming:Archive) throws {
        _ = try incoming.validated(); try store?.replace(with:incoming); archive = incoming; blocked = false
        activeID = nil; editingID = nil; notifications?.refresh(archive); applyLanguage(); newDraft(); refresh(rebuild:true)
    }
    @objc private func resetAction() { guard confirm(tr(language,"Tüm kayıtlar sıfırlansın mı? Orijinal kurtarma kopyasında kalacak.","Reset all records? The original will remain in a recovery copy.")) else { return }; do { try replace(Archive()); message = "" } catch { message = error.localizedDescription }; updateStatus() }
    @objc private func folderAction() { if let directory = store?.directory { try? FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true); NSWorkspace.shared.open(directory) } }
    @objc private func sampleAction() { if change({ value in
        let date = now()
        try value.put(Card(kind:.announcement,scene:.desk,ink:.aqua,title:tr(language,"Bir fikrin peşindeyim. Az sonra döneceğim.","Following an idea. I will be back soon."),body:tr(language,"Kurgusal örnek · metni kendi sözlerinle değiştir.","Fictional sample · make the wording your own."),pinned:true,now:date))
        try value.put(Card(kind:.note,scene:.desk,ink:.rose,title:tr(language,"Bugünün tek küçük adımı","One small step today"),body:tr(language,"İlk taslağı tamamla. Geri kalanı sonra.","Finish the first draft. The rest can wait."),now:date.addingTimeInterval(-1)))
        try value.put(Card(kind:.reminder,scene:.pause,ink:.amber,title:tr(language,"Bir pencere molası","A window break"),body:tr(language,"Örnek hatırlatma · 25 dakika sonra.","Sample reminder · in 25 minutes."),now:date,dueAt:date.addingTimeInterval(25*60)))
    }) { message = tr(language,"Üç örnek kart eklendi. Bildirim izni kendiliğinden istenmez.","Three sample cards added. Notification permission is not requested automatically."); updateStatus() } }
    @objc private func breakAction() { guard mayLeaveDraft() else { return }; newDraft(kind:.reminder,title:tr(language,"Kısa mola","Short break"),body:tr(language,"Pencereden dışarı bak, biraz hareket et.","Look outside and stretch a little.")); window?.makeFirstResponder(titleField) }
    @objc private func motionAction() { _ = change { $0.settings.motion.toggle() } }

    override func makeTouchBar() -> NSTouchBar? {
        let bar = NSTouchBar(); bar.delegate = self; bar.defaultItemIdentifiers = [.postScenes,.postRail,.postQuick,.postPrivacy]; bar.principalItemIdentifier = .postRail; return bar
    }
    func touchBar(_ touchBar:NSTouchBar,makeItemForIdentifier identifier:NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == .postScenes {
            let item = NSPopoverTouchBarItem(identifier:identifier); item.collapsedRepresentationLabel = archive.settings.scene.name(language); item.showsCloseButton = true
            let choices = NSTouchBar(); choices.delegate = self; choices.defaultItemIdentifiers = Scene.allCases.map { .scene($0) }; item.popoverTouchBar = choices; scenePopover = item; return item
        }
        if identifier == .postRail {
            let item = NSCustomTouchBarItem(identifier:identifier), rail = RailView(frame:NSRect(x:0,y:0,width:600,height:30)); wire(rail)
            rail.translatesAutoresizingMaskIntoConstraints = false; rail.heightAnchor.constraint(equalToConstant:30).isActive = true; rail.widthAnchor.constraint(greaterThanOrEqualToConstant:240).isActive = true
            let preferred = rail.widthAnchor.constraint(equalToConstant:600); preferred.priority = .defaultLow; preferred.isActive = true
            rail.setContentCompressionResistancePriority(.defaultLow,for:.horizontal); item.view = rail; physicalRail = rail
            rail.update(card:displayed,privacy:archive.settings.privacy,motion:archive.settings.motion && !hold,language:language); return item
        }
        if identifier == .postQuick || identifier == .postPrivacy {
            let item = NSCustomTouchBarItem(identifier:identifier), control = NSButton(title:identifier == .postQuick ? "+" : (archive.settings.privacy ? "○" : "◉"),target:self,action:identifier == .postQuick ? #selector(quickAction) : #selector(privacyAction))
            control.setAccessibilityLabel(identifier == .postQuick ? tr(language,"Yeni not","New note") : tr(language,"Perdeyi aç veya kapat","Toggle curtain"))
            if identifier == .postPrivacy { privacyTouchButton = control }; item.view = control; return item
        }
        for (index,scene) in Scene.allCases.enumerated() where identifier == .scene(scene) {
            let item = NSCustomTouchBarItem(identifier:identifier), control = NSButton(title:scene.name(language),target:self,action:#selector(touchScene(_:))); control.tag = index; item.view = control; return item
        }
        return nil
    }
    @objc private func touchScene(_ sender:NSButton) { chooseScene(Scene.allCases[sender.tag]) }
}
