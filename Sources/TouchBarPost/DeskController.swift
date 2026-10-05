import AppKit
import PostCore

extension NSTouchBarItem.Identifier {
    static let postRail = Self("com.metealpkarvan.TouchBarPost.rail")
    static let postQuick = Self("com.metealpkarvan.TouchBarPost.quick")
}
final class MessageView: NSTextView {
    var placeholder = "Mesajını yaz…" { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect:NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty { (placeholder as NSString).draw(at:NSPoint(x:9,y:8),withAttributes:[.font:NSFont.systemFont(ofSize:14),.foregroundColor:NSColor.postMuted]) }
    }
}
final class MessageRow: NSButton {
    var card:Card!
    var selectedMessage = false
    var language:Language = .tr
    var date = Date()
    override func draw(_ dirtyRect:NSRect) {
        let color = card.kind == .reminder ? Ink.amber.color : Ink.aqua.color
        (selectedMessage ? color.withAlphaComponent(0.15) : NSColor.postPanel).setFill()
        NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:2),xRadius:7,yRadius:7).fill()
        let paragraph=NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        (Archive.oneLine(card.messageText) as NSString).draw(in:NSRect(x:12,y:25,width:bounds.width-24,height:19),withAttributes:[.font:NSFont.systemFont(ofSize:13,weight:.medium),.foregroundColor:NSColor.postWhite,.paragraphStyle:paragraph])
        let caption=card.kind.name(language)+(card.dueAt.map { " · "+(card.isDue(at:date) ? tr(language,"Vakti geldi","Ready now") : DateFormatter.localizedString(from:$0,dateStyle:.short,timeStyle:.short)) } ?? "")
        (caption as NSString).draw(in:NSRect(x:12,y:7,width:bounds.width-24,height:16),withAttributes:[.font:NSFont.systemFont(ofSize:10),.foregroundColor:color,.paragraphStyle:paragraph])
    }
}
final class DeskController: NSWindowController, NSTouchBarDelegate, NSWindowDelegate, NSTextViewDelegate, NSMenuItemValidation {
    private(set) var archive:Archive
    let store:ArchiveStore?
    let notifications:NotificationDesk?
    private(set) var blocked = false
    private(set) var editingID:UUID?
    private var activeID:UUID?
    private var lastDueIDs:Set<UUID> = []
    private var lastList:[Card] = []
    private var timer:Timer?, animation:Timer?
    private var physicalRail:RailView?
    private var statusItem:NSStatusItem?
    private var loadingEditor = false
    private var message = ""
    private var hasError = false
    let kinds:[CardKind] = [.note,.reminder,.announcement]
    var kind=NSSegmentedControl()
    let messageField=MessageView(),dueField=NSDatePicker(),preview=RailView(frame:.zero)
    var saveButton=NSButton(),newButton=NSButton(),deleteButton=NSButton(),finishButton=NSButton(),snoozeButton=NSButton()
    var timeButtons:[NSButton] = []
    private let dateRow=NSView(),messageScroll=NSScrollView(),listScroll=NSScrollView()
    private var subtitle=NSTextField(),hint=NSTextField(),listTitle=NSTextField(),status=NSTextField()
    var now:()->Date
    var copyText:(String)->Void = { text in NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text,forType:.string) }
    var language:Language { archive.settings.language }
    var selectedKind:CardKind { kinds[max(0,min(2,kind.selectedSegment))] }
    var displayed:Card? { archive.simpleQueue(at:now()).first { $0.id == activeID } }
    var hasDraftChanges:Bool {
        guard let c=archive.cards.first(where:{$0.id==editingID}) else { return !messageField.string.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty }
        return messageField.string != c.messageText || selectedKind != c.kind || (c.kind == .reminder && abs(dueField.dateValue.timeIntervalSince(c.dueAt!))>=1)
    }
    init(store:ArchiveStore?=nil,archive initial:Archive=Archive(),timers:Bool=true,notifications:NotificationDesk?=nil,statusItem:Bool=true,now:@escaping ()->Date=Date.init) {
        self.store=store; self.notifications=notifications; self.now=now; archive=initial
        if let store=store { do { archive=try store.load() } catch { blocked=true; hasError=true; message="Kayıt açılamadı. Veriler menüsünden yedeği yükle veya önceki kaydı kurtar. / Use Data to restore a backup or recover the previous archive." } }
        activeID=archive.settings.selectedCardID
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:640,height:590),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title="Şerit"; window.appearance=NSAppearance(named:.darkAqua); window.isReleasedWhenClosed=false
        super.init(window:window); window.delegate=self; build(); window.touchBar=makeTouchBar(); messageField.touchBar=window.touchBar; dueField.touchBar=window.touchBar
        if statusItem { self.statusItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength) }
        notifications?.onError = { [weak self] text in self?.message=text; self?.hasError=true; self?.updateStatus() }
        notifications?.onOpen = { [weak self] id in self?.showDesk(); if let id=id { self?.selectCard(id) } }
        newDraft(); applyLanguage(); refresh(rebuild:true)
        if let selected=displayed { loadEditor(selected) }
        if timers {
            timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in self?.refresh(rebuild:false) }
            let frames=Timer(timeInterval:1.0/30,repeats:true) { [weak self] _ in
                guard let self=self,NSApp.isActive else { return }; self.preview.animate(delta:1.0/30); self.physicalRail?.animate(delta:1.0/30)
            }; RunLoop.main.add(frames,forMode:.common); animation=frames
        }
        notifications?.refresh(archive); window.center()
    }
    required init?(coder:NSCoder) { fatalError() }
    deinit { timer?.invalidate(); animation?.invalidate(); if let item=statusItem { NSStatusBar.system.removeStatusItem(item) } }
    private func build() {
        let root=Canvas(frame:NSRect(x:0,y:0,width:640,height:590)); window?.contentView=root
        _=label("Şerit",NSRect(x:24,y:17,width:590,height:36),size:27,weight:.semibold,in:root)
        subtitle=label("",NSRect(x:24,y:58,width:590,height:22),size:12,color:.postMuted,in:root)
        kind=NSSegmentedControl(labels:["Not","Hatırlatıcı","Duyuru"],trackingMode:.selectOne,target:self,action:#selector(kindChanged))
        kind.frame=NSRect(x:22,y:89,width:414,height:32); kind.selectedSegment=0; root.addSubview(kind)
        newButton=button("Yeni",NSRect(x:530,y:89,width:88,height:32),target:self,action:#selector(newAction),in:root)
        messageScroll.frame=NSRect(x:24,y:134,width:592,height:94); messageScroll.hasVerticalScroller=true; messageScroll.borderType = .bezelBorder
        messageField.frame=NSRect(x:0,y:0,width:574,height:94); messageField.delegate=self; messageField.isRichText=false; messageField.allowsUndo=true; messageField.font = .systemFont(ofSize:14); messageField.textColor = .postWhite; messageField.insertionPointColor = .postWhite; messageField.backgroundColor = .postPanel; messageField.textContainerInset=NSSize(width:8,height:8); messageField.isVerticallyResizable=true; messageField.autoresizingMask = [.width]; messageField.textContainer?.widthTracksTextView=true; messageScroll.documentView=messageField; root.addSubview(messageScroll)
        hint=label("",NSRect(x:24,y:245,width:592,height:23),size:12,color:.postMuted,in:root)
        dateRow.frame=NSRect(x:24,y:238,width:592,height:34); root.addSubview(dateRow)
        dueField.frame=NSRect(x:0,y:3,width:284,height:27); dueField.datePickerStyle = .textFieldAndStepper; dueField.datePickerElements=[.yearMonthDay,.hourMinute]; dueField.target=self; dueField.action=#selector(dateChanged); dateRow.addSubview(dueField)
        for (i,minutes) in [5,15,60].enumerated() { let b=button("+\(minutes) dk",NSRect(x:302+i*95,y:1,width:91,height:30),target:self,action:#selector(timeAction(_:)),in:dateRow); b.tag=minutes; timeButtons.append(b) }
        saveButton=button("Kaydet",NSRect(x:20,y:285,width:219,height:34),target:self,action:#selector(saveAction),in:root); saveButton.bezelColor=Ink.aqua.color
        finishButton=button("Tamamla",NSRect(x:245,y:285,width:137,height:34),target:self,action:#selector(finishAction),in:root)
        snoozeButton=button("+5 dk ertele",NSRect(x:386,y:285,width:138,height:34),target:self,action:#selector(snoozeAction),in:root)
        deleteButton=button("Sil",NSRect(x:531,y:285,width:89,height:34),target:self,action:#selector(deleteAction),in:root)
        _=label("Touch Bar",NSRect(x:24,y:334,width:592,height:18),size:11,color:.postMuted,in:root)
        preview.frame=NSRect(x:24,y:357,width:592,height:38); wire(preview); root.addSubview(preview)
        listTitle=label("",NSRect(x:24,y:415,width:592,height:23),size:13,weight:.medium,in:root)
        listScroll.frame=NSRect(x:24,y:440,width:592,height:103); listScroll.hasVerticalScroller=true; listScroll.drawsBackground=false; root.addSubview(listScroll)
        status=label("",NSRect(x:24,y:552,width:592,height:30),size:10,color:.postMuted,in:root)
    }
    private func wire(_ rail:RailView) {
        rail.onPrevious={ [weak self] in self?.cycle(-1) }; rail.onNext={ [weak self] in self?.cycle(1) }
        rail.onOpen={ [weak self] in guard let self=self else { return }; self.showDesk(); if let id=self.displayed?.id { self.selectCard(id) } else { self.newAction() } }
        rail.onAction={ [weak self] in self?.stripAction() }
    }
    func applyLanguage() {
        subtitle.stringValue=tr(language,"Yaz. Kaydet. Touch Bar’da gör.","Write. Save. See it on your Touch Bar.")
        for (i,k) in kinds.enumerated() { kind.setLabel(k == .reminder ? tr(language,"Hatırlatıcı","Reminder") : k.name(language),forSegment:i) }
        newButton.title=tr(language,"Yeni","New"); deleteButton.title=tr(language,"Sil","Delete"); finishButton.title=tr(language,"Tamamla","Done"); snoozeButton.title=tr(language,"+5 dk ertele","Snooze 5 min")
        for b in timeButtons { b.title=tr(language,"+\(b.tag) dk","+\(b.tag) min") }
        messageField.placeholder=tr(language,"Mesajını yaz…","Write your message…")
        dueField.locale=Locale(identifier:language == .tr ? "tr_TR" : "en_US")
        messageField.setAccessibilityLabel(tr(language,"Mesaj","Message")); kind.setAccessibilityLabel(tr(language,"Mesaj türü","Message type")); dueField.setAccessibilityLabel(tr(language,"Hatırlatma zamanı","Reminder time"))
        updateEditor(); refresh(rebuild:true)
    }
    @discardableResult func change(_ mutation:(inout Archive)throws->Void)->Bool {
        guard !blocked else { message=tr(language,"Kayıt korunuyor. Veriler menüsünden yedek yükle veya önceki kaydı kurtar.","Save protected. Restore a backup or recover the previous archive from Data."); hasError=true; updateStatus(); return false }
        do {
            var next=archive; try mutation(&next); next=try next.validated(); try store?.save(next)
            let reschedule=next.cards != archive.cards || next.settings.notifications != archive.settings.notifications || next.settings.privacy != archive.settings.privacy || next.settings.language != archive.settings.language
            archive=next; hasError=false; message=""; if reschedule { notifications?.refresh(next) }; refresh(rebuild:true); return true
        } catch { message=tr(language,"Kaydedilemedi; mesajın korunuyor. ","Could not save; your message is retained. ")+error.localizedDescription; hasError=true; updateStatus(); return false }
    }
    func refresh(rebuild:Bool) {
        let list=archive.simpleQueue(at:now()),dueIDs=Set(list.filter{$0.isDue(at:now())}.map(\.id)),newIDs=dueIDs.subtracting(lastDueIDs)
        let dueChanged=dueIDs != lastDueIDs
        if let next=list.first(where:{newIDs.contains($0.id)}) { activeID=next.id }
        lastDueIDs=dueIDs
        if !list.contains(where:{$0.id==activeID}) { activeID=list.first?.id }
        for rail in [preview,physicalRail].compactMap({$0}) { rail.update(card:displayed,privacy:archive.settings.privacy,motion:archive.settings.motion,language:language); rail.previous.isEnabled=list.count>1; rail.next.isEnabled=list.count>1 }
        if rebuild || dueChanged || list != lastList { rebuildList(list) }; lastList=list; updateEditor(); updateStatus(); updateMenu()
    }
    private func rebuildList(_ cards:[Card]) {
        listTitle.stringValue=tr(language,"Kaydedilenler · \(cards.count)","Saved messages · \(cards.count)")
        let document=Canvas(frame:NSRect(x:0,y:0,width:574,height:max(103,cards.count*53)))
        if cards.isEmpty { _=label(tr(language,"Henüz mesaj yok. Yukarıya bir şey yazıp kaydet.","No messages yet. Write something above and save."),NSRect(x:12,y:20,width:550,height:54),size:12,color:.postMuted,in:document) }
        for (i,c) in cards.enumerated() {
            let row=MessageRow(frame:NSRect(x:0,y:i*53,width:574,height:51)); row.card=c; row.selectedMessage=c.id==activeID; row.language=language; row.date=now(); row.identifier=NSUserInterfaceItemIdentifier(c.id.uuidString); row.target=self; row.action=#selector(rowAction(_:)); row.setAccessibilityLabel(c.messageText); document.addSubview(row)
        }; listScroll.documentView=document
    }
    private func updateEditor() {
        dateRow.isHidden=selectedKind != .reminder; hint.isHidden=selectedKind == .reminder
        hint.stringValue=selectedKind == .announcement ? tr(language,"Uzun duyuru Touch Bar’da kayar.","Long announcements scroll across the Touch Bar.") : tr(language,"Seçtiğin not şeritte kalır.","Your chosen note stays on the strip.")
        let saved=archive.cards.first{$0.id==editingID && $0.doneAt==nil}
        saveButton.title=tr(language,"Kaydet","Save"); saveButton.isEnabled = !blocked && !messageField.string.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
        deleteButton.isEnabled = !blocked && saved != nil
        finishButton.isHidden=saved?.kind != .reminder || selectedKind != .reminder; snoozeButton.isHidden=finishButton.isHidden
        finishButton.isEnabled = !blocked && saved?.kind == .reminder; snoozeButton.isEnabled=finishButton.isEnabled
    }
    func textDidChange(_ notification:Notification) { guard !loadingEditor else { return }; messageField.needsDisplay=true; message=""; hasError=false; updateEditor(); updateStatus() }
    @objc func dateChanged() { message=""; updateStatus() }
    @objc func kindChanged() { message=""; updateEditor(); updateStatus() }
    @objc func timeAction(_ sender:NSButton) { guard [5,15,60].contains(sender.tag) else { return }; dueField.dateValue=now().addingTimeInterval(Double(sender.tag)*60); dateChanged() }
    private func loadEditor(_ card:Card) {
        loadingEditor=true; editingID=card.id; kind.selectedSegment=kinds.firstIndex(of:card.kind)!; messageField.string=card.messageText; dueField.dateValue=card.dueAt ?? now().addingTimeInterval(15*60); loadingEditor=false; messageField.needsDisplay=true; updateEditor()
    }
    func newDraft() {
        loadingEditor=true; editingID=nil; kind.selectedSegment=0; messageField.string=""; dueField.dateValue=now().addingTimeInterval(15*60); loadingEditor=false; messageField.needsDisplay=true; updateEditor()
    }
    @discardableResult func saveMessage()->Bool {
        let date=now(),old=archive.cards.first{$0.id==editingID}
        var card=old ?? Card(kind:selectedKind,ink:selectedKind == .reminder ? .amber : .aqua,title:"",now:date)
        do { try card.setMessageText(messageField.string) } catch { message=tr(language,"Mesaj çok uzun veya boş. Kısaltıp tekrar kaydet.","The message is too long or empty. Shorten it and save again."); hasError=true; updateStatus(); return false }
        card.kind=selectedKind; card.dueAt=selectedKind == .reminder ? dueField.dateValue : nil; card.updatedAt=date
        guard change({ try $0.put(card); $0.settings.selectedCardID=card.id }) else { return false }
        activeID=card.id; loadEditor(card); message=tr(language,"Kaydedildi.","Saved."); refresh(rebuild:true); return true
    }
    @objc func saveAction() { _=saveMessage() }
    /// Valid text saves when switching messages, closing the window or quitting.
    func mayLeaveDraft()->Bool { !hasDraftChanges || messageField.string.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || saveMessage() }
    @objc func newAction() { guard mayLeaveDraft() else { return }; newDraft(); message=""; updateStatus(); window?.makeFirstResponder(messageField) }
    func selectCard(_ id:UUID) {
        guard archive.cards.contains(where:{$0.id==id && $0.doneAt==nil}),mayLeaveDraft(),let card=archive.cards.first(where:{$0.id==id && $0.doneAt==nil}) else { return }
        guard archive.settings.selectedCardID==id || change({$0.settings.selectedCardID=id}) else { return }
        activeID=id; loadEditor(card); message=""; refresh(rebuild:true)
    }
    @objc private func rowAction(_ sender:MessageRow) { if let id=sender.identifier.flatMap({UUID(uuidString:$0.rawValue)}) { selectCard(id) } }
    func cycle(_ direction:Int) {
        let list=archive.simpleQueue(at:now()); guard !list.isEmpty else { return }; let i=list.firstIndex{$0.id==activeID} ?? 0; selectCard(list[(i+direction+list.count)%list.count].id)
    }
    @objc func quickAction() { showDesk(); newAction() }
    func stripAction() {
        guard !archive.settings.privacy,let card=displayed else { return }
        if card.kind == .reminder { complete(card.id) }
        else { copyText(card.messageText); message=tr(language,"Kopyalandı.","Copied."); updateStatus() }
    }
    private func complete(_ id:UUID) {
        if editingID==id && !mayLeaveDraft() { return }
        guard archive.cards.first(where:{$0.id==id})?.kind == .reminder,change({try $0.finish(id,at:now())}) else { return }
        if editingID==id { newDraft() }; message=tr(language,"Hatırlatıcı tamamlandı.","Reminder completed."); refresh(rebuild:true)
    }
    @objc func finishAction() { if let id=editingID { complete(id) } }
    @objc func snoozeAction() {
        guard let id=editingID,mayLeaveDraft() else { return }; if change({try $0.snooze(id,minutes:5,at:now())}) { if let c=archive.cards.first(where:{$0.id==id}) { loadEditor(c) }; activeID=id; message=tr(language,"5 dakika ertelendi.","Snoozed for 5 minutes."); refresh(rebuild:true) }
    }
    @objc func deleteAction() {
        guard let id=editingID else { return }; if change({$0.remove(id)}) { newDraft(); message=tr(language,"Mesaj silindi.","Message deleted."); refresh(rebuild:true) }
    }
    @objc func privacyAction() { if change({$0.settings.privacy.toggle()}) { refresh(rebuild:true) } }
    @objc func languageAction() { if change({$0.settings.language = language == .tr ? .en : .tr}) { applyLanguage() } }
    @objc func notificationsAction() {
        guard let notifications=notifications else { message=tr(language,"Sistem bildirimleri için paketlenmiş Şerit.app’i aç.","Open the packaged Şerit.app for system notifications."); updateStatus(); return }
        if archive.settings.notifications { _=change{$0.settings.notifications=false}; return }
        notifications.authorize { [weak self] allowed,error in guard let self=self else { return }; if allowed { _=self.change{$0.settings.notifications=true} } else { self.message=error ?? tr(self.language,"Bildirim izni verilmedi. Touch Bar çalışmaya devam eder.","Notifications were not allowed. The Touch Bar still works."); self.hasError=true; self.updateStatus() } }
    }
    private func updateStatus() {
        status.textColor=hasError ? Ink.rose.color : .postMuted
        if !message.isEmpty { status.stringValue=message }
        else if archive.settings.privacy { status.stringValue=tr(language,"Touch Bar metni gizli. Şerit menüsünden tekrar gösterebilirsin.","Touch Bar text is hidden. Show it again from the Şerit menu.") }
        else { let due=archive.cards.filter{$0.isDue(at:now())}.count; status.stringValue=due>0 ? tr(language,"\(due) hatırlatıcının vakti geldi. ✓ ile tamamla.","\(due) reminders are ready. Tap ✓ to finish.") : tr(language,"Touch Bar uygulama öndeyken görünür. Mesajların bu Mac’te saklanır.","The Touch Bar appears while the app is frontmost. Messages stay on this Mac.") }
    }
    func showDesk() { guard NSApp.activationPolicy() != .prohibited else { return }; showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }
    func windowShouldClose(_ sender:NSWindow)->Bool { mayLeaveDraft() }
    private func item(_ title:String,_ action:Selector,_ menu:NSMenu,_ value:String?=nil) { let i=NSMenuItem(title:title,action:action,keyEquivalent:""); i.target=self; i.representedObject=value; menu.addItem(i) }
    private func updateMenu() {
        guard let statusItem=statusItem else { return }; let due=archive.cards.filter{$0.isDue(at:now())}.count
        statusItem.button?.title=due>0 ? "✎ \(due)" : "✎"; statusItem.button?.setAccessibilityLabel("Şerit")
        let menu=NSMenu(); item(tr(language,"Şerit’i aç","Open Şerit"),#selector(showAction),menu); item(tr(language,"Yeni not","New note"),#selector(quickAction),menu)
        for c in archive.cards.filter({$0.isDue(at:now())}).sorted(by:Archive.dueOrder).prefix(3) { item((archive.settings.privacy ? tr(language,"Hatırlatıcı","Reminder") : c.title)+" · "+tr(language,"Vakti geldi","Ready"),#selector(openCardMenu(_:)),menu,c.id.uuidString) }
        menu.addItem(.separator()); item(tr(language,"Sistem bildirimleri","System notifications"),#selector(notificationsAction),menu); item(tr(language,"Touch Bar metnini gizle","Hide Touch Bar text"),#selector(privacyAction),menu); item(language == .tr ? "English" : "Türkçe",#selector(languageAction),menu)
        menu.addItem(.separator()); item(tr(language,"Çık","Quit"),#selector(NSApplication.terminate(_:)),menu); menu.items.last?.target=NSApp; statusItem.menu=menu
    }
    @objc func showAction() { showDesk() }
    @objc private func openCardMenu(_ sender:NSMenuItem) { showDesk(); if let s=sender.representedObject as? String,let id=UUID(uuidString:s) { selectCard(id) } }
    func validateMenuItem(_ menuItem:NSMenuItem)->Bool {
        if menuItem.action == #selector(privacyAction) { menuItem.state=archive.settings.privacy ? .on : .off }
        if menuItem.action == #selector(notificationsAction) { menuItem.state=archive.settings.notifications ? .on : .off }
        return true
    }
    private func confirm(_ title:String)->Bool { let a=NSAlert(); a.messageText=title; a.addButton(withTitle:tr(language,"Yükle","Restore")); a.addButton(withTitle:tr(language,"Vazgeç","Cancel")); return a.runModal() == .alertFirstButtonReturn }
    @objc func exportAction() {
        do { let data=try blocked && store != nil ? Data(contentsOf:store!.file) : archive.encoded(); let panel=NSSavePanel(); panel.allowedFileTypes=["json"]; panel.nameFieldStringValue=blocked ? "serit-original.json" : "serit-backup.json"; if panel.runModal() == .OK,let url=panel.url { try data.write(to:url,options:.atomic) } } catch { message=error.localizedDescription; hasError=true; updateStatus() }
    }
    @objc func importAction() {
        guard mayLeaveDraft() else { return }; let panel=NSOpenPanel(); panel.allowedFileTypes=["json"]; panel.canChooseDirectories=false; panel.allowsMultipleSelection=false
        guard panel.runModal() == .OK,let url=panel.url else { return }
        do { let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0; guard size<=1_048_576 else { throw PostError.invalid("Maximum 1 MB") }; var incoming=try Archive.decode(Data(contentsOf:url)); incoming.settings.notifications=false
            guard confirm(tr(language,"Yedek mevcut mesajların yerine yüklensin mi? Mevcut dosyanın kurtarma kopyası tutulur.","Replace messages with this backup? A recovery copy of the current file is kept.")) else { return }; try replace(incoming)
        } catch { message=error.localizedDescription; hasError=true; updateStatus() }
    }
    func replace(_ incoming:Archive)throws {
        _=try incoming.validated(); try store?.replace(with:incoming); archive=incoming; blocked=false; activeID=incoming.settings.selectedCardID; lastDueIDs=[]; notifications?.refresh(incoming); newDraft(); applyLanguage(); refresh(rebuild:true); if let c=displayed { loadEditor(c) }
    }
    @objc func recoverAction() {
        guard let store=store,mayLeaveDraft() else { return }
        do { let url=store.directory.appendingPathComponent("archive.previous.json"),size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0; guard size<=1_048_576 else { throw PostError.invalid("Maximum 1 MB") }; var old=try Archive.decode(Data(contentsOf:url)); old.settings.notifications=false
            guard confirm(tr(language,"Önceki kayıt geri yüklensin mi? Mevcut ham dosya ayrıca korunur.","Restore the previous archive? The current raw file is kept separately.")) else { return }; try replace(old)
        } catch { message=tr(language,"Önceki kayıt yüklenemedi. ","Could not recover previous archive. ")+error.localizedDescription; hasError=true; updateStatus() }
    }
    @objc func markdownAction() { do { let panel=NSSavePanel(); panel.nameFieldStringValue="serit-notes.md"; if panel.runModal() == .OK,let url=panel.url { try Data(archive.markdown().utf8).write(to:url,options:.atomic) } } catch { message=error.localizedDescription; hasError=true; updateStatus() } }
    @objc func folderAction() { if let dir=store?.directory { try? FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true); NSWorkspace.shared.open(dir) } }
    override func makeTouchBar()->NSTouchBar { let bar=NSTouchBar(); bar.delegate=self; bar.defaultItemIdentifiers=[.postRail,.postQuick]; bar.principalItemIdentifier = .postRail; return bar }
    func touchBar(_ touchBar:NSTouchBar,makeItemForIdentifier id:NSTouchBarItem.Identifier)->NSTouchBarItem? {
        if id == .postRail {
            let item=NSCustomTouchBarItem(identifier:id),rail=RailView(frame:NSRect(x:0,y:0,width:600,height:30)); wire(rail); rail.widthAnchor.constraint(greaterThanOrEqualToConstant:240).isActive=true; rail.heightAnchor.constraint(equalToConstant:30).isActive=true; item.view=rail; physicalRail=rail; rail.update(card:displayed,privacy:archive.settings.privacy,motion:archive.settings.motion,language:language); return item
        }
        if id == .postQuick { let item=NSCustomTouchBarItem(identifier:id),b=NSButton(title:"+",target:self,action:#selector(quickAction)); b.setAccessibilityLabel(tr(language,"Yeni not","New note")); item.view=b; return item }; return nil
    }
}
