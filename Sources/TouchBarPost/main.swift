import AppKit
import PostCore
import UserNotifications

final class PostDelegate:NSObject,NSApplicationDelegate {
    var controller:DeskController?,notifications:NotificationDesk?
    func applicationDidFinishLaunching(_ notification:Notification) {
        if Bundle.main.bundleIdentifier == "com.metealpkarvan.TouchBarPost" { notifications=NotificationDesk() }
        let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("TouchBarPost",isDirectory:true)
        let desk=DeskController(store:ArchiveStore(directory:directory),notifications:notifications); controller=desk; menus(desk); desk.showDesk()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { false }
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply { controller?.mayLeaveDraft() == false ? .terminateCancel : .terminateNow }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool { controller?.showDesk(); return true }
    func applicationSupportsSecureRestorableState(_ app:NSApplication)->Bool { true }
    private func menus(_ desk:DeskController) {
        let root=NSMenu(); NSApp.mainMenu=root
        func menu(_ name:String)->NSMenu { let item=NSMenuItem(); root.addItem(item); let m=NSMenu(title:name); item.submenu=m; return m }
        func add(_ name:String,_ action:Selector,_ key:String,_ m:NSMenu,_ target:AnyObject) { let item=NSMenuItem(title:name,action:action,keyEquivalent:key); item.target=target; m.addItem(item) }
        let app=menu("Şerit"); add("Şerit Hakkında / About",#selector(aboutAction),"",app,self)
        app.addItem(.separator()); add("Sistem bildirimleri / Notifications",#selector(DeskController.notificationsAction),"",app,desk); add("Touch Bar metnini gizle / Hide text",#selector(DeskController.privacyAction),"",app,desk); add("Türkçe / English",#selector(DeskController.languageAction),"",app,desk)
        app.addItem(.separator()); add("GitHub · Kaynak / Source",#selector(sourceAction),"",app,self); add("Çık / Quit Şerit",#selector(NSApplication.terminate(_:)),"q",app,NSApp)
        let edit=menu("Düzen / Edit")
        for (name,action,key) in [("Geri al / Undo",Selector(("undo:")),"z"),("Kes / Cut",#selector(NSText.cut(_:)),"x"),("Kopyala / Copy",#selector(NSText.copy(_:)),"c"),("Yapıştır / Paste",#selector(NSText.paste(_:)),"v"),("Tümünü seç / Select All",#selector(NSText.selectAll(_:)),"a")] { edit.addItem(NSMenuItem(title:name,action:action,keyEquivalent:key)) }
        let messages=menu("Mesaj / Message"); add("Yeni / New",#selector(DeskController.quickAction),"n",messages,desk); add("Kaydet / Save",#selector(DeskController.saveAction),"s",messages,desk)
        let data=menu("Veriler / Data")
        for (name,action) in [("JSON yedekle / Export JSON",#selector(DeskController.exportAction)),("Yedek yükle / Restore JSON",#selector(DeskController.importAction)),("Önceki kaydı kurtar / Recover previous",#selector(DeskController.recoverAction)),("Markdown çıktısı / Export Markdown",#selector(DeskController.markdownAction)),("Kayıt klasörü / Data folder",#selector(DeskController.folderAction))] { add(name,action,"",data,desk) }
    }
    @objc private func aboutAction() { NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"Şerit",.applicationVersion:"1.1.0",.credits:NSAttributedString(string:"Not. Hatırlatıcı. Duyuru.\nNote. Reminder. Announcement.\nMete Alp Karvan · MIT · 2026")]) }
    @objc private func sourceAction() { NSWorkspace.shared.open(URL(string:"https://github.com/metealpkarvan/touch-bar-post")!) }
}
func png(_ view:NSView,_ url:URL)throws {
    view.layoutSubtreeIfNeeded(); guard let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) else { throw PostError.invalid("Image unavailable") }; view.cacheDisplay(in:view.bounds,to:bitmap)
    guard let data=bitmap.representation(using:.png,properties:[:]) else { throw PostError.invalid("Image unavailable") }; try data.write(to:url)
}
func smoke(_ screenshots:URL?)throws {
    var checks=0
    func check(_ value:@autoclosure ()throws->Bool,_ name:String)throws { guard try value() else { throw PostError.invalid("FAIL "+name) }; checks+=1; print("PASS "+name) }
    let date=Date(timeIntervalSince1970:1_791_180_000),temp=FileManager.default.temporaryDirectory.appendingPathComponent("serit-simple-"+UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:temp) }
    var original=Archive()
    let note=Card(kind:.note,scene:.home,ink:.rose,title:"Bugünün tek işi",body:"İlk taslağı bitir.",pinned:true,now:date)
    let banner=Card(kind:.announcement,scene:.pause,ink:.lime,title:"Toplantıdayım. Saat 15:00’ten sonra döneceğim.",body:"Beni beklemeden devam edebilirsin.",now:date.addingTimeInterval(-1))
    let reminder=Card(kind:.reminder,scene:.home,title:"Çayı unutma",body:"Beş dakika sonra hazır.",now:date.addingTimeInterval(-2),dueAt:date.addingTimeInterval(5*60))
    for c in [note,banner,reminder] { try original.put(c) }
    original.settings.scene = .pause
    let store=ArchiveStore(directory:temp); try store.save(original)
    let desk=DeskController(store:store,timers:false,statusItem:false,now:{date})
    var copied=""; desk.copyText={copied=$0}
    try check(desk.archive==original && desk.messageField.string==note.messageText,"Existing messages and all metadata open unchanged in a single editor")
    try check(desk.archive.simpleQueue(at:date).count==3,"Messages from all previous scenes are visible")
    guard let bar=desk.window?.touchBar,let physical=(bar.item(forIdentifier:.postRail) as? NSCustomTouchBarItem)?.view as? RailView,let quick=(bar.item(forIdentifier:.postQuick) as? NSCustomTouchBarItem)?.view as? NSButton else { throw PostError.invalid("Touch Bar items missing") }
    try check(bar.defaultItemIdentifiers == [.postRail,.postQuick],"Touch Bar has only a message strip and new-note button")
    try check(desk.kind.segmentCount==3 && desk.kinds == [.note,.reminder,.announcement],"Main editor has exactly three message types")
    desk.selectCard(note.id); physical.act.performClick(nil)
    try check(copied==note.messageText,"Actual copy action preserves full text using an isolated test clipboard")
    let selected=desk.displayed?.id; desk.now={date.addingTimeInterval(120)}; desk.refresh(rebuild:false)
    try check(desk.displayed?.id==selected,"A selected note never rotates automatically")
    physical.next.performClick(nil); try check(desk.displayed?.id==banner.id && desk.messageField.string==banner.messageText,"Touch Bar next selects and opens the next message")
    physical.previous.performClick(nil); try check(desk.displayed?.id==note.id,"Touch Bar previous uses the same selection path")
    let savedNote=desk.archive.cards.first{$0.id==note.id}!
    desk.messageField.string="Notu tek alanda düzenledim.\nEski kayıt biçimi korunuyor."; desk.saveButton.performClick(nil)
    let edited=desk.archive.cards.first{$0.id==note.id}!
    try check(edited.id==savedNote.id && edited.scene==savedNote.scene && edited.ink==savedNote.ink && edited.pinned==savedNote.pinned && edited.createdAt==savedNote.createdAt,"One-field editing preserves legacy identity, scene, ink, pin and creation date")
    try check(edited.messageText==desk.messageField.string && !desk.hasDraftChanges,"Save produces canonical text without a dirty editor")
    desk.messageField.string="Gezinirken kaydedilen not"; desk.selectCard(note.id)
    try check(desk.archive.cards.first{$0.id==note.id}?.title=="Gezinirken kaydedilen not" && desk.messageField.string=="Gezinirken kaydedilen not" && !desk.hasDraftChanges,"Selecting the same message auto-saves valid edits without reloading stale text")
    desk.selectCard(banner.id); let reopened=DeskController(store:ArchiveStore(directory:temp),timers:false,statusItem:false,now:{date})
    try check(reopened.displayed?.id==banner.id && reopened.messageField.string==banner.messageText,"Chosen message persists after reopening")
    try check(physical.stamp.animated == !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,"Only announcements scroll when motion is allowed")
    desk.selectCard(note.id); try check(!physical.stamp.animated,"Notes remain still even with motion enabled")
    quick.performClick(nil); desk.messageField.string="Yeni not"; desk.saveAction()
    let newID=desk.archive.settings.selectedCardID!
    try check(desk.archive.cards.count==4 && desk.displayed?.id==newID,"One-field quick note saves and displays immediately")
    desk.newAction(); desk.kind.selectedSegment=1; desk.kindChanged(); desk.messageField.string="Su iç"; desk.timeButtons[1].performClick(nil); desk.saveAction()
    let newReminder=desk.archive.cards.first{$0.id==desk.archive.settings.selectedCardID}!
    try check(newReminder.kind == .reminder && newReminder.dueAt==desk.now().addingTimeInterval(15*60),"Reminder-only fifteen-minute shortcut saves the intended time")
    desk.timeButtons[0].performClick(nil); try check(desk.dueField.dateValue==desk.now().addingTimeInterval(5*60),"Five-minute shortcut uses the current wall clock")
    desk.timeButtons[2].performClick(nil); try check(desk.dueField.dateValue==desk.now().addingTimeInterval(60*60),"Sixty-minute shortcut uses the current wall clock")
    desk.saveAction(); desk.selectCard(note.id); desk.messageField.string="Taslağım kalsın"; desk.languageAction()
    try check(desk.archive.settings.language == .en && desk.messageField.string=="Taslağım kalsın" && desk.dueField.locale?.identifier == "en_US","Language switch preserves unsaved text and updates the date input locale")
    desk.languageAction(); desk.messageField.string=desk.archive.cards.first{$0.id==note.id}!.messageText
    desk.now={date.addingTimeInterval(301)}; desk.refresh(rebuild:false)
    try check(desk.displayed?.id==reminder.id && physical.stamp.card?.id==reminder.id,"A newly due reminder takes priority across all former scenes")
    desk.selectCard(reminder.id); desk.snoozeButton.performClick(nil)
    try check(desk.archive.cards.first{$0.id==reminder.id}?.dueAt==desk.now().addingTimeInterval(300) && !desk.displayed!.isDue(at:desk.now()),"Actual snooze button postpones the selected reminder five minutes")
    desk.now={date.addingTimeInterval(602)}; desk.refresh(rebuild:false); physical.act.performClick(nil)
    try check(desk.archive.cards.first{$0.id==reminder.id}?.doneAt != nil && !desk.archive.simpleQueue(at:desk.now()).contains(where:{$0.id==reminder.id}),"Touch Bar checkmark completes the reminder and removes it from the active list")
    desk.selectCard(newID); desk.deleteButton.performClick(nil)
    try check(!desk.archive.cards.contains(where:{$0.id==newID}) && desk.archive.settings.selectedCardID != newID,"Delete removes only the selected message and clears its saved selection")
    desk.selectCard(banner.id); desk.privacyAction()
    try check(desk.archive.settings.privacy && physical.stamp.concealed && !physical.act.isEnabled,"Menu privacy preference still conceals text and prevents copying")
    let quiet=DeskController(store:ArchiveStore(directory:temp),timers:false,statusItem:false,now:{date})
    try check(quiet.archive.settings.privacy && quiet.preview.stamp.concealed,"Existing privacy preferences survive reopening")
    desk.privacyAction(); try check(!physical.stamp.concealed,"Menu privacy toggle reveals the strip again")
    let req=notificationRequest(newReminder,settings:desk.archive.settings)!
    try check(req.identifier=="serit."+newReminder.id.uuidString && (req.trigger as? UNCalendarNotificationTrigger)?.repeats == false && req.content.sound==nil,"Reminders retain quiet one-shot local notification requests")
    var hidden=desk.archive.settings; hidden.privacy=true; let generic=notificationRequest(newReminder,settings:hidden)!
    try check(!generic.content.title.contains(newReminder.title) && !generic.content.body.contains(newReminder.body),"Privacy remains effective for scheduled notification text")
    if let folder=screenshots {
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        desk.selectCard(note.id); try png(desk.window!.contentView!,folder.appendingPathComponent("desktop.png")); desk.languageAction(); try png(desk.window!.contentView!,folder.appendingPathComponent("desktop-en.png")); desk.languageAction()
        desk.selectCard(newReminder.id); try png(desk.window!.contentView!,folder.appendingPathComponent("desktop-reminder.png"))
        physical.frame=NSRect(x:0,y:0,width:600,height:30); physical.layoutButtons(); physical.update(card:banner,privacy:false,motion:true,language:.tr); physical.animate(delta:3); try png(physical,folder.appendingPathComponent("touchbar-announcement.png"))
        physical.update(card:reminder,privacy:false,motion:false,language:.tr); try png(physical,folder.appendingPathComponent("touchbar-reminder.png"))
        physical.update(card:note,privacy:false,motion:false,language:.tr); try png(physical,folder.appendingPathComponent("touchbar-note.png"))
        physical.update(card:note,privacy:true,motion:false,language:.tr); try png(physical,folder.appendingPathComponent("touchbar-curtain.png"))
    }
    let raw=Data("unreadable-original-archive".utf8); try raw.write(to:store.file)
    let blocked=DeskController(store:store,timers:false,statusItem:false,now:{date}); blocked.messageField.string="Korunması gereken taslak"; blocked.saveAction()
    try check(try Data(contentsOf:store.file)==raw && blocked.blocked,"Actual simplified editor cannot overwrite corrupt user data")
    let denied=temp.appendingPathComponent("blocked-path"); try Data("file".utf8).write(to:denied)
    let failed=DeskController(store:ArchiveStore(directory:denied),timers:false,statusItem:false,now:{date}); failed.messageField.string="Kaybolmayan taslak"; failed.saveAction()
    try check(failed.archive.cards.isEmpty && failed.messageField.string=="Kaybolmayan taslak" && failed.hasDraftChanges,"Failed save keeps the draft and archive untouched")
    try check(!failed.mayLeaveDraft(),"Unwritable storage prevents losing an unsaved draft during navigation")
    try FileManager.default.removeItem(at:denied); failed.saveAction()
    try check(failed.archive.cards.count==1 && !failed.hasDraftChanges && (try ArchiveStore(directory:denied).load())==failed.archive,"Retry saves the same draft once after storage repair")
    failed.messageField.string=String(repeating:"a",count:482); let before=failed.archive; failed.saveAction()
    try check(failed.archive==before && failed.messageField.string.count==482,"Overlong text is retained and cannot partially change a saved message")
    print("\(checks) AppKit integration checks passed. No permission request, live user records, clipboard or visible windows changed.")
}
let app=NSApplication.shared
if CommandLine.arguments.contains("--smoke-test") {
    app.setActivationPolicy(.prohibited); let args=CommandLine.arguments
    let folder=args.firstIndex(of:"--screenshots").flatMap { args.indices.contains($0+1) ? URL(fileURLWithPath:args[$0+1],isDirectory:true) : nil }
    do { try smoke(folder); exit(0) } catch { fputs("Smoke failed: \(error)\n",stderr); exit(1) }
} else { app.setActivationPolicy(.regular); let delegate=PostDelegate(); app.delegate=delegate; app.run() }
