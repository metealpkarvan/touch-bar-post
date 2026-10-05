import AppKit
import PostCore
import UserNotifications

final class PostDelegate: NSObject, NSApplicationDelegate {
    var controller: DeskController?
    var notifications: NotificationDesk?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if Bundle.main.bundleIdentifier == "com.metealpkarvan.TouchBarPost" { notifications = NotificationDesk() }
        let directory = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("TouchBarPost",isDirectory:true)
        let desk = DeskController(store:ArchiveStore(directory:directory),notifications:notifications)
        controller = desk; menus(desk); desk.showDesk()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender:NSApplication) -> NSApplication.TerminateReply { controller?.mayLeaveDraft() == false ? .terminateCancel : .terminateNow }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool) -> Bool { controller?.showDesk(); return true }
    func applicationSupportsSecureRestorableState(_ app:NSApplication) -> Bool { true }
    private func menus(_ desk:DeskController) {
        let menu = NSMenu(); NSApp.mainMenu = menu
        let app = NSMenuItem(); menu.addItem(app); let appMenu = NSMenu(title:"Şerit"); app.submenu = appMenu
        let about = NSMenuItem(title:"Şerit Hakkında / About",action:#selector(aboutAction),keyEquivalent:""); about.target = self; appMenu.addItem(about)
        let source = NSMenuItem(title:"GitHub · Kaynak Kod / Source",action:#selector(sourceAction),keyEquivalent:""); source.target = self; appMenu.addItem(source)
        appMenu.addItem(.separator()); appMenu.addItem(NSMenuItem(title:"Çık / Quit Şerit",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"))
        let edit = NSMenuItem(); menu.addItem(edit); let editMenu = NSMenu(title:"Düzen / Edit"); edit.submenu = editMenu
        for (title,action,key) in [("Geri al / Undo",Selector(("undo:")),"z"),("Kes / Cut",#selector(NSText.cut(_:)),"x"),("Kopyala / Copy",#selector(NSText.copy(_:)),"c"),("Yapıştır / Paste",#selector(NSText.paste(_:)),"v"),("Tümünü seç / Select All",#selector(NSText.selectAll(_:)),"a")] { editMenu.addItem(NSMenuItem(title:title,action:action,keyEquivalent:key)) }
        let card = NSMenuItem(); menu.addItem(card); let cards = NSMenu(title:"Kart / Card"); card.submenu = cards
        for (title,action,key) in [("Yeni not / New note",#selector(DeskController.quickAction),"n"),("Kaydet / Save",#selector(DeskController.saveAction),"s"),("Perde / Curtain",#selector(DeskController.privacyAction),"p")] { let item = NSMenuItem(title:title,action:action,keyEquivalent:key); item.target = desk; cards.addItem(item) }
    }
    @objc private func aboutAction() {
        NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"Şerit · Touch Bar Post",.applicationVersion:"1.0.0",.credits:NSAttributedString(string:"Duyurular, hatırlatmalar ve kısa notlar.\nAnnouncements, reminders and little notes.\nMete Alp Karvan · MIT · 2026")])
    }
    @objc private func sourceAction() { NSWorkspace.shared.open(URL(string:"https://github.com/metealpkarvan/touch-bar-post")!) }
}

func png(_ view:NSView,_ url:URL) throws {
    view.layoutSubtreeIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else { throw PostError.invalid("Cannot allocate image") }
    view.cacheDisplay(in:view.bounds,to:bitmap)
    guard let data = bitmap.representation(using:.png,properties:[:]) else { throw PostError.invalid("Cannot render image") }
    try data.write(to:url)
}
func smoke(_ screenshots:URL?) throws {
    var checks = 0
    func check(_ condition:@autoclosure () throws -> Bool,_ title:String) throws { guard try condition() else { throw PostError.invalid(title) }; checks += 1; print("PASS \(title)") }
    let date = Date(timeIntervalSince1970:1_791_180_000)
    var archive = Archive()
    let banner = Card(kind:.announcement,ink:.aqua,title:"Bir fikrin peşindeyim. Az sonra döneceğim.",body:"Kurgusal örnek · Şerit senin küçük duyuru panon.",pinned:true,now:date)
    let note = Card(kind:.note,ink:.rose,title:"Bugünün tek küçük adımı",body:"İlk taslağı tamamla. Geri kalanı sonra.",now:date.addingTimeInterval(-1))
    let alarm = Card(kind:.reminder,scene:.pause,ink:.amber,title:"Pencere molası",body:"Biraz hareket et, uzaklara bak.",now:date,dueAt:date.addingTimeInterval(25*60))
    for card in [banner,note,alarm] { try archive.put(card) }
    let desk = DeskController(archive:archive,timers:false,statusItem:false,now:{ date })
    guard let bar = desk.window?.touchBar,
          let popover = bar.item(forIdentifier:.postScenes) as? NSPopoverTouchBarItem,
          let strip = (bar.item(forIdentifier:.postRail) as? NSCustomTouchBarItem)?.view as? RailView,
          let quick = (bar.item(forIdentifier:.postQuick) as? NSCustomTouchBarItem)?.view as? NSButton,
          let privacy = (bar.item(forIdentifier:.postPrivacy) as? NSCustomTouchBarItem)?.view as? NSButton else { throw PostError.invalid("Missing Touch Bar factory items") }
    try check(popover.popoverTouchBar.defaultItemIdentifiers.count == 3,"Three scene buttons")
    desk.refresh(rebuild:true); try check(strip.stamp.card?.id == banner.id,"Pinned announcement rendered on physical-item view")
    strip.next.performClick(nil); try check(desk.displayed?.id == note.id,"Touch Bar next navigates")
    strip.previous.performClick(nil); try check(desk.displayed?.id == banner.id,"Touch Bar previous navigates")
    privacy.performClick(nil); try check(desk.archive.settings.privacy && strip.stamp.concealed && !strip.act.isEnabled,"Curtain masks strip and disables copying")
    privacy.performClick(nil); try check(!strip.stamp.concealed,"Curtain can be reopened")
    quick.performClick(nil); desk.titleField.stringValue = "Tek dokunuşluk not"; desk.bodyField.string = "Kurgusal test"
    desk.saveAction(); try check(desk.archive.cards.count == 4,"Quick note creates a real card through native form")
    let saved = desk.archive.cards.last!; desk.selectCard(saved.id); desk.titleField.stringValue = "Güncellenmiş not"
    try check(desk.hasDraftChanges,"Unsaved editor changes are detected")
    desk.saveAction(); try check(!desk.hasDraftChanges,"Successful save clears dirty state")
    try check(desk.archive.cards.count == 4 && desk.archive.cards.last?.title == "Güncellenmiş not","Editing preserves card identity")
    desk.chooseScene(.pause); desk.now = { date.addingTimeInterval(26*60) }; desk.refresh(rebuild:true)
    try check(desk.displayed?.id == alarm.id,"Reminder becomes due after wall-clock advance")
    desk.preview.act.performClick(nil); try check(desk.archive.cards.first(where: { $0.id == alarm.id })?.doneAt != nil,"Preview completion uses shared reminder action")
    desk.chooseScene(.home); try check(desk.archive.settings.scene == .home,"Scene mutation works")
    desk.now = { date }; desk.chooseScene(.desk); desk.selectCard(banner.id)
    let request = notificationRequest(alarm,settings:archive.settings)!
    try check(request.identifier == "serit." + alarm.id.uuidString,"Notification has stable card identifier")
    try check(request.content.title == alarm.title && (request.trigger as? UNCalendarNotificationTrigger)?.repeats == false,"One-shot notification content and trigger")
    var settings = archive.settings; settings.privacy = true
    let hidden = notificationRequest(alarm,settings:settings)!
    try check(!hidden.content.title.contains(alarm.title) && !hidden.content.body.contains(alarm.body),"Curtain masks scheduled notification content")
    try check(request.content.sound == nil,"Reminder scheduling is quiet by default")
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent("serit-smoke-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:temp) }
    let store = ArchiveStore(directory:temp); try store.save(archive)
    let reopened = DeskController(store:store,timers:false,statusItem:false,now:{ date })
    try check(reopened.archive == archive,"AppKit desk reopens saved archive")
    let bad = Data("original-invalid-json".utf8); try bad.write(to:store.file)
    let guarded = DeskController(store:store,timers:false,statusItem:false,now:{ date })
    guarded.titleField.stringValue = "Do not overwrite"; guarded.saveAction()
    try check(try Data(contentsOf:store.file) == bad,"Corrupt archive is protected by the actual editor")
    if let folder = screenshots {
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        if let root = desk.window?.contentView { try png(root,folder.appendingPathComponent("desktop.png")) }
        let controls = desk.window!.contentView!.subviews.compactMap { $0 as? NSButton }
        let languageButton = controls.first(where: { $0.title == "English" })!
        desk.bodyField.string = "An unsaved draft stays here."
        languageButton.performClick(nil)
        try check(desk.archive.settings.language == .en && desk.bodyField.string == "An unsaved draft stays here.","Language switch preserves unsaved text")
        desk.bodyField.string = banner.body
        try png(desk.window!.contentView!,folder.appendingPathComponent("desktop-en.png"))
        languageButton.performClick(nil)
        try check(desk.archive.settings.language == .tr && desk.bodyField.string == banner.body,"Language switch returns to Turkish")
        strip.frame = NSRect(x:0,y:0,width:600,height:30); strip.layoutButtons(); strip.update(card:banner,privacy:false,motion:false,language:.tr)
        try png(strip,folder.appendingPathComponent("touchbar-announcement.png"))
        strip.update(card:alarm,privacy:false,motion:false,language:.tr); try png(strip,folder.appendingPathComponent("touchbar-reminder.png"))
        strip.update(card:note,privacy:true,motion:false,language:.tr); try png(strip,folder.appendingPathComponent("touchbar-curtain.png"))
    }
    print("\(checks) AppKit integration checks passed. No notification permission requested; no live user records or clipboard changed.")
}
let app = NSApplication.shared
if CommandLine.arguments.contains("--smoke-test") {
    app.setActivationPolicy(.prohibited)
    let args = CommandLine.arguments
    let folder = args.firstIndex(of:"--screenshots").flatMap { args.indices.contains($0+1) ? URL(fileURLWithPath:args[$0+1],isDirectory:true) : nil }
    do { try smoke(folder); exit(0) } catch { fputs("Smoke failed: \(error)\n",stderr); exit(1) }
} else {
    app.setActivationPolicy(.regular); let delegate = PostDelegate(); app.delegate = delegate; app.run()
}
