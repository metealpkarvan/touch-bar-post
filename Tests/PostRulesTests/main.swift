import Foundation
import PostCore

var checked = 0, failed = 0
let date = Date(timeIntervalSince1970:1_791_180_000)
func test(_ title:String,_ body:() throws -> Void) { checked += 1; do { try body(); print("PASS \(title)") } catch { failed += 1; print("FAIL \(title): \(error)") } }
func expect(_ value:@autoclosure () throws -> Bool,_ message:String = "Unexpected result") throws { if try !value() { throw PostError.invalid(message) } }
func rejects(_ body:() throws -> Void) throws { var rejected = false; do { try body() } catch { rejected = true }; try expect(rejected,"Expected rejection") }
func card(_ kind:CardKind = .note,_ title:String = "Not",scene:Scene = .desk,pinned:Bool = false,due:Double? = nil) -> Card { Card(kind:kind,scene:scene,title:title,pinned:pinned,now:date,dueAt:due.map { date.addingTimeInterval($0) }) }
func archive(_ cards:[Card]) -> Archive { var value = Archive(); value.cards = cards; return value }
func settingsJSON(_ changes:[String:Any] = [:], removing:[String] = []) throws -> Data {
    var root = try JSONSerialization.jsonObject(with:Archive().encoded()) as! [String:Any]
    var settings = root["settings"] as! [String:Any]
    for key in removing { settings.removeValue(forKey:key) }
    for (key,value) in changes { settings[key] = value }
    root["settings"] = settings
    return try JSONSerialization.data(withJSONObject:root)
}

test("Empty archive and privacy defaults") { let a = try Archive().validated(); try expect(a.cards.isEmpty && !a.settings.notifications && !a.settings.privacy && a.settings.scene == .desk && a.settings.touchBarWidth == Settings.defaultTouchBarWidth) }
test("Touch Bar width accepts both inclusive boundaries") {
    for width in [Settings.minimumTouchBarWidth,Settings.defaultTouchBarWidth,Settings.maximumTouchBarWidth] {
        var a = Archive(); a.settings.touchBarWidth = width
        try expect(try Archive.decode(a.encoded()) == a)
    }
}
test("Touch Bar width rejects out-of-range values in memory and JSON") {
    for width in [Settings.minimumTouchBarWidth - 1,Settings.maximumTouchBarWidth + 1,0,Int.max] {
        var a = Archive(); a.settings.touchBarWidth = width
        try rejects { _ = try a.validated() }
        try rejects { _ = try a.encoded() }
        try rejects { _ = try Archive.decode(settingsJSON(["touchBarWidth":width])) }
    }
}
test("Present width rejects null and invalid JSON types instead of migrating") {
    let invalid:[Any] = [NSNull(),true,"400",400.5,[],["width":400]]
    for value in invalid { try rejects { _ = try Archive.decode(settingsJSON(["touchBarWidth":value])) } }
}
test("Legacy migration defaults only missing width without relaxing required fields") {
    let a = try Archive.decode(settingsJSON(removing:["touchBarWidth","selectedCardID"]))
    try expect(a.settings.touchBarWidth == 400 && a.settings.selectedCardID == nil)
    for key in ["scene","privacy","motion","notifications","language"] {
        try rejects { _ = try Archive.decode(settingsJSON(removing:["touchBarWidth",key])) }
        try rejects { _ = try Archive.decode(settingsJSON([key:NSNull()],removing:["touchBarWidth"])) }
    }
    // The previously optional selection retains its v1 nil representation.
    let nullSelection = try Archive.decode(settingsJSON(["selectedCardID":NSNull()],removing:["touchBarWidth"]))
    try expect(nullSelection.settings.selectedCardID == nil && nullSelection.settings.touchBarWidth == 400)
    try rejects { _ = try Archive.decode(settingsJSON(["selectedCardID":17],removing:["touchBarWidth"])) }
}
test("Whitespace-only title rejected") { try rejects { _ = try archive([card(.note," \n ")]).validated() } }
test("80 grapheme title boundary") { _ = try archive([card(.note,String(repeating:"ş",count:80))]).validated(); try rejects { _ = try archive([card(.note,String(repeating:"ş",count:81))]).validated() } }
test("400 grapheme body boundary") { var c = card(); c.body = String(repeating:"🧑🏽‍💻",count:400); _ = try archive([c]).validated(); c.body += "a"; try rejects { _ = try archive([c]).validated() } }
test("New card trims surrounding whitespace") { let c = Card(kind:.note,title:"  Bir not \n",body:"  İçerik  ",now:date); try expect(c.title == "Bir not" && c.body == "İçerik") }
test("Single message exposes title and optional body") {
    var c = card(.note,"Title"); try expect(c.messageText == "Title")
    c.body = "Line one\nLine two"; try expect(c.messageText == "Title\nLine one\nLine two")
}
test("Short message becomes one title and clears prior body") {
    var c = card(); c.body = "Old body"; try c.setMessageText("  One message  \n")
    try expect(c.title == "One message" && c.body.isEmpty && c.messageText == "One message")
}
test("Single editor prefers first newline within title limit") {
    var c = card(); try c.setMessageText("  First line \n Second line\nThird line  ")
    try expect(c.title == "First line" && c.body == "Second line\nThird line")
    try c.setMessageText("First\r\nSecond"); try expect(c.title == "First" && c.body == "Second")
}
test("Long first line splits at eighty graphemes") {
    var c = card(); let prefix = String(repeating:"ş",count:80)
    try c.setMessageText(prefix + "More text\nFinal line")
    try expect(c.title == prefix && c.body == "More text\nFinal line")
    try c.setMessageText(String(repeating:"x",count:480))
    try expect(c.title.count == 80 && c.body.count == 400 && c.messageText.count == 481)
}
test("Emoji message boundaries count graphemes rather than scalar or byte length") {
    let emoji = "🧑🏽‍💻"; var c = card()
    try c.setMessageText(String(repeating:emoji,count:80) + "\n" + String(repeating:emoji,count:400))
    try expect(c.title.count == 80 && c.body.count == 400)
    _ = try archive([c]).validated()
    let before = c; try rejects { try c.setMessageText(String(repeating:emoji,count:481)) }; try expect(c == before)
}
test("Unchanged legacy message preserves unusual field boundaries and metadata") {
    var c = card(.reminder,"Old\nmultiline title",scene:.home,pinned:true,due:3600)
    c.ink = .rose; c.body = "  Body whitespace\nsecond line  "; c.updatedAt = date.addingTimeInterval(123)
    let before = c
    try c.setMessageText(" \n" + c.messageText + "\n ")
    try expect(c == before,"Unchanged message rewrote a legacy field or metadata")
    try c.setMessageText("New message\nNew body")
    var expected = before; expected.title = "New message"; expected.body = "New body"
    try expect(c == expected,"Editing message changed unrelated metadata")
}
test("Message rejection is atomic for blank input and oversized body") {
    var blank = Card(kind:.note,title:"",now:date); try rejects { try blank.setMessageText(" \n ") }
    var c = card(.announcement,"Original",scene:.pause,pinned:true); c.body = "Keep"; let before = c
    for invalid in [" \n \t", "Short\n" + String(repeating:"x",count:401), String(repeating:"x",count:482)] {
        try rejects { try c.setMessageText(invalid) }; try expect(c == before)
    }
}
test("Reminder requires date") { try rejects { _ = try archive([card(.reminder)]).validated() } }
test("Note cannot carry reminder date") { try rejects { _ = try archive([card(.note,due:60)]).validated() } }
test("Announcement cannot carry reminder date") { try rejects { _ = try archive([card(.announcement,due:60)]).validated() } }
test("Unknown archive version rejected") { var a = Archive(); a.version = 2; try rejects { _ = try a.validated() } }
test("Duplicate identities rejected") { let c = card(); try rejects { _ = try archive([c,c]).validated() } }
test("Capacity admits 200 and rejects 201") { _ = try archive((0..<200).map { card(.note,"\($0)") }).validated(); try rejects { _ = try archive((0..<201).map { card(.note,"\($0)") }).validated() } }
test("Nonfinite and out-of-range dates rejected") { var c = card(); c.createdAt = Date(timeIntervalSince1970:.infinity); try rejects { _ = try archive([c]).validated() }; c.createdAt = Date(timeIntervalSince1970:-1); try rejects { _ = try archive([c]).validated() } }
test("ISO backup roundtrip preserves content and settings") { var a = archive([card(.reminder,"Çay ☕",due:180)]); a.settings.privacy = true; a.settings.language = .en; try expect(try Archive.decode(a.encoded()) == a) }
test("Selected strip message roundtrip preserves identity") {
    let c = card(.note,scene:.home); var a = archive([c]); a.settings.selectedCardID = c.id
    try expect(try Archive.decode(a.encoded()) == a)
}
test("Selected strip rejects a missing or completed reference") {
    let c = card(); var a = archive([c]); a.settings.selectedCardID = UUID()
    try rejects { _ = try a.validated() }
    a.settings.selectedCardID = c.id; a.cards[0].doneAt = date
    try rejects { _ = try a.validated() }
}
test("Invalid JSON rejected") { try rejects { _ = try Archive.decode(Data("{bad".utf8)) } }
test("Oversized backup rejected before decoding") { try rejects { _ = try Archive.decode(Data(repeating:32,count:1_048_577)) } }
test("Unknown kind rejected by schema") { let a = try archive([card()]).encoded(); let text = String(data:a,encoding:.utf8)!.replacingOccurrences(of:"\"note\"",with:"\"executable\""); try rejects { _ = try Archive.decode(Data(text.utf8)) } }
test("Due boundary is inclusive") { let c = card(.reminder,due:0); try expect(c.isDue(at:date) && !c.isDue(at:date.addingTimeInterval(-1))) }
test("Due reminders cross scene boundaries") { let c = card(.reminder,scene:.home,due:-60); try expect(archive([c,card(.note)]).queue(at:date).first?.id == c.id) }
test("Future reminders stay in their scene") { let c = card(.reminder,scene:.home,due:60); try expect(archive([c]).queue(at:date).isEmpty) }
test("Due reminders precede pinned notes") { let c = card(.reminder,due:-60); try expect(archive([card(.note,pinned:true),c]).queue(at:date).first?.id == c.id) }
test("Earliest due first") { let a = card(.reminder,due:-120), b = card(.reminder,due:-60); try expect(archive([b,a]).queue(at:date).map(\.id) == [a.id,b.id]) }
test("Pinned scene cards before unpinned") { let c = card(.note,pinned:true); try expect(archive([card(.announcement),c]).queue(at:date).first?.id == c.id) }
test("Newest scene card first with stable ties") { var a = card(); a.createdAt = date.addingTimeInterval(-1); let b = card(); try expect(archive([a,b]).queue(at:date).first?.id == b.id); try expect(archive([b,a]).queue(at:date) == archive([a,b]).queue(at:date)) }
test("Due card included exactly once") { let c = card(.reminder,due:-5); try expect(archive([c]).queue(at:date).count == 1) }
test("Simple list exposes active cards from every old scene") {
    let desk = card(.note,"Desk"), pause = card(.announcement,"Pause",scene:.pause), home = card(.reminder,"Home",scene:.home,due:3600)
    var a = archive([home,pause,desk]); a.settings.scene = .desk
    try expect(Set(a.simpleQueue(at:date).map(\.id)) == Set([desk.id,pause.id,home.id]))
    a.settings.scene = .home
    try expect(a.simpleQueue(at:date) == archive([home,pause,desk]).simpleQueue(at:date))
    try expect(archive([home,pause,desk]).queue(at:date).map(\.id) == [desk.id],"Legacy scene filtering changed")
}
test("Simple list excludes completed records of every kind") {
    let cards = [card(.note,scene:.desk),card(.announcement,scene:.pause),card(.reminder,scene:.home,due:-5)]
    var a = archive(cards)
    for c in cards { try a.finish(c.id,at:date) }
    try expect(a.simpleQueue(at:date).isEmpty)
    try a.restore(cards[1].id,at:date)
    try expect(a.simpleQueue(at:date).map(\.id) == [cards[1].id])
}
test("Simple list prioritizes due reminders before pinned and newer cards") {
    let past = card(.reminder,"Due",scene:.home,due:-60), boundary = card(.reminder,"Now",scene:.pause,due:0)
    let pinned = card(.note,"Pinned",pinned:true), future = card(.reminder,"Future",scene:.home,due:60)
    let a = archive([future,pinned,boundary,past])
    let ids = a.simpleQueue(at:date).map(\.id)
    try expect(ids == [past.id,boundary.id,pinned.id,future.id])
    try expect(Set(ids).count == ids.count,"Due record was duplicated")
}
test("Simple due ordering uses earliest date then stable identity") {
    var a = card(.reminder,"A",scene:.home,due:-60), b = card(.reminder,"B",scene:.pause,due:-60), c = card(.reminder,"Earlier",due:-120)
    a.id = UUID(uuidString:"00000000-0000-0000-0000-000000000001")!
    b.id = UUID(uuidString:"00000000-0000-0000-0000-000000000002")!
    b.pinned = true; b.createdAt = date.addingTimeInterval(1)
    try expect(archive([b,a,c]).simpleQueue(at:date).map(\.id) == [c.id,a.id,b.id])
}
test("Simple ordinary ordering is pinned then creation time then identity") {
    var oldPinned = card(.note,"Old pinned",scene:.home,pinned:true), newPinned = card(.announcement,"New pinned",scene:.pause,pinned:true)
    var a = card(.note,"A"), b = card(.reminder,"B",scene:.home,due:60)
    oldPinned.createdAt = date.addingTimeInterval(-120); newPinned.createdAt = date.addingTimeInterval(-60)
    a.id = UUID(uuidString:"00000000-0000-0000-0000-000000000001")!
    b.id = UUID(uuidString:"00000000-0000-0000-0000-000000000002")!
    a.updatedAt = date.addingTimeInterval(100)
    let input = [b,oldPinned,a,newPinned]
    try expect(archive(input).simpleQueue(at:date).map(\.id) == [newPinned.id,oldPinned.id,a.id,b.id])
    try expect(archive(Array(input.reversed())).simpleQueue(at:date) == archive(input).simpleQueue(at:date))
}
test("Simple list is empty for empty archive and leaves archive unchanged") {
    let empty = Archive(); try expect(empty.simpleQueue(at:date).isEmpty)
    let a = archive([card(.note,scene:.home),card(.reminder,scene:.pause,due:60)])
    let before = a; _ = a.simpleQueue(at:date)
    try expect(a == before)
}
test("Version one fixture preserves hidden metadata while simple list reveals cards") {
    let fixture = Data("""
    {"version":1,"settings":{"scene":"pause","privacy":true,"motion":false,"notifications":true,"language":"en"},"cards":[
      {"id":"00000000-0000-0000-0000-000000000001","kind":"note","scene":"home","ink":"rose","title":"Old home note","body":"Line one\\nLine two","pinned":true,"createdAt":"2026-10-05T05:00:00Z","updatedAt":"2026-10-05T05:01:00Z"},
      {"id":"00000000-0000-0000-0000-000000000002","kind":"reminder","scene":"desk","ink":"aqua","title":"Old deadline","body":"","pinned":false,"createdAt":"2026-10-05T05:00:00Z","updatedAt":"2026-10-05T05:00:00Z","dueAt":"2026-10-06T05:00:00Z"},
      {"id":"00000000-0000-0000-0000-000000000003","kind":"announcement","scene":"pause","ink":"lime","title":"Already done","body":"Keep this history","pinned":false,"createdAt":"2026-10-05T05:00:00Z","updatedAt":"2026-10-05T05:01:00Z","doneAt":"2026-10-05T05:01:00Z"}
    ]}
    """.utf8)
    let a = try Archive.decode(fixture)
    try expect(a.version == 1 && a.settings.scene == .pause && a.settings.privacy && !a.settings.motion && a.settings.notifications && a.settings.language == .en && a.settings.selectedCardID == nil && a.settings.touchBarWidth == 400)
    try expect(a.cards[0].scene == .home && a.cards[0].ink == .rose && a.cards[0].pinned && a.cards[0].body == "Line one\nLine two")
    try expect(a.cards[2].doneAt != nil && a.queue(at:date).isEmpty)
    try expect(a.simpleQueue(at:date).map(\.title) == ["Old home note","Old deadline"])
    try expect(try Archive.decode(a.encoded()) == a,"Simplification changed the existing archive format")
}
test("Version 1.1 selected-note fixture migrates width without changing saved notes") {
    let fixture = Data("""
    {"version":1,"settings":{"scene":"home","privacy":false,"motion":true,"notifications":false,"language":"tr","selectedCardID":"00000000-0000-0000-0000-000000000002"},"cards":[
      {"id":"00000000-0000-0000-0000-000000000001","kind":"note","scene":"pause","ink":"rose","title":"Birinci not","body":"Özgün metin","pinned":true,"createdAt":"2026-10-05T05:00:00Z","updatedAt":"2026-10-05T05:01:00Z"},
      {"id":"00000000-0000-0000-0000-000000000002","kind":"note","scene":"home","ink":"lime","title":"İkinci not","body":"Bağımsız metin","pinned":false,"createdAt":"2026-10-05T06:00:00Z","updatedAt":"2026-10-05T06:01:00Z"}
    ]}
    """.utf8)
    let a = try Archive.decode(fixture)
    try expect(a.version == 1 && a.settings.touchBarWidth == 400 && a.settings.selectedCardID == a.cards[1].id)
    try expect(a.cards.count == 2 && a.cards[0].ink == .rose && a.cards[0].pinned && a.cards[0].scene == .pause)
    try expect(a.cards[1].ink == .lime && a.cards[1].body == "Bağımsız metin" && a.cards[1].createdAt != a.cards[0].createdAt)
    try expect(try Archive.decode(a.encoded()) == a)
}
test("Width roundtrip retains distinct notes even when titles match") {
    var first = card(.note,"Aynı başlık",scene:.home,pinned:true)
    first.ink = .rose; first.body = "Birinci içerik"; first.updatedAt = date.addingTimeInterval(45)
    var second = card(.note,"Aynı başlık",scene:.pause)
    second.ink = .lime; second.body = "İkinci içerik"; second.createdAt = date.addingTimeInterval(60); second.updatedAt = second.createdAt
    var done = card(.note,"Tamamlanmış",scene:.desk)
    done.doneAt = date.addingTimeInterval(30)
    var a = archive([first,second,done]); a.settings.touchBarWidth = 520; a.settings.selectedCardID = second.id
    let restored = try Archive.decode(a.encoded())
    try expect(restored == a && restored.version == 1 && restored.cards[0].id != restored.cards[1].id)
    var edited = restored.cards[0]; try edited.setMessageText("Düzenlenen ilk not"); edited.updatedAt = date.addingTimeInterval(120)
    var updated = restored; try updated.put(edited)
    try expect(updated.cards.count == 3 && updated.cards[1] == second && updated.cards[2] == done)
    try expect(updated.settings == a.settings && updated.cards[0].createdAt == first.createdAt && updated.cards[0].pinned && updated.cards[0].ink == .rose)
}
test("Completion removes reminders from display and notifications") { let c = card(.reminder,due:60); var a = archive([c]); try a.finish(c.id,at:date); try expect(a.queue(at:date).isEmpty && a.notificationCards(at:date).isEmpty) }
test("Completion is idempotent") { let c = card(); var a = archive([c]); try a.finish(c.id,at:date); try a.finish(c.id,at:date.addingTimeInterval(9)); try expect(a.cards[0].doneAt == date) }
test("Completion clears selected message while preserving another selection") {
    let a = card(), b = card(.note,"Other"); var value = archive([a,b]); value.settings.selectedCardID = a.id
    try value.finish(b.id,at:date); try expect(value.settings.selectedCardID == a.id)
    try value.finish(a.id,at:date); try expect(value.settings.selectedCardID == nil && value.cards.allSatisfy { $0.doneAt != nil })
    try value.restore(a.id,at:date); try expect(value.settings.selectedCardID == nil)
}
test("Rejected completion preserves message selection atomically") {
    let c = card(); var a = archive([c]); a.settings.selectedCardID = c.id; let before = a
    try rejects { try a.finish(c.id,at:Date(timeIntervalSince1970:-1)) }
    try expect(a == before)
}
test("Restore preserves deadline and identity") { let c = card(.reminder,due:-60); var a = archive([c]); try a.finish(c.id,at:date); try a.restore(c.id,at:date); try expect(a.cards[0].id == c.id && a.cards[0].dueAt == c.dueAt && a.cards[0].isDue(at:date)) }
test("Snooze starts from current time") { let c = card(.reminder,due:-3600); var a = archive([c]); try a.snooze(c.id,minutes:5,at:date); try expect(a.cards[0].dueAt == date.addingTimeInterval(300) && !a.cards[0].isDue(at:date)) }
test("Invalid snooze leaves archive unchanged") { let c = card(.reminder,due:1); var a = archive([c]); let before = a; try rejects { try a.snooze(c.id,minutes:0,at:date) }; try expect(a == before); try rejects { try a.snooze(c.id,minutes:1441,at:date) } }
test("Cannot snooze notes or completed reminders") { let c = card(); var a = archive([c]); try rejects { try a.snooze(c.id,minutes:5,at:date) }; let r = card(.reminder,due:60); try a.put(r); try a.finish(r.id,at:date); try rejects { try a.snooze(r.id,minutes:5,at:date) } }
test("Editing replaces by identity") { var c = card(); var a = archive([c]); c.title = "Edited"; try a.put(c); try expect(a.cards.count == 1 && a.cards[0].title == "Edited") }
test("Invalid edit cannot partially mutate") { let c = card(); var a = archive([c]); var bad = c; bad.title = ""; try rejects { try a.put(bad) }; try expect(a.cards[0] == c) }
test("Deletion cancels notification plan") { let c = card(.reminder,due:60); var a = archive([c]); a.remove(c.id); try expect(a.notificationCards(at:date).isEmpty) }
test("Deletion clears only the removed selected identity") {
    let a = card(), b = card(.note,"Other"); var value = archive([a,b]); value.settings.selectedCardID = a.id
    value.remove(b.id); try expect(value.settings.selectedCardID == a.id)
    value.remove(UUID()); try expect(value.settings.selectedCardID == a.id)
    value.remove(a.id); try expect(value.settings.selectedCardID == nil && value.cards.isEmpty)
}
test("Missing mutation targets rejected") { var a = Archive(); try rejects { try a.finish(UUID(),at:date) }; try rejects { try a.restore(UUID(),at:date) } }
test("Notification plan omits due or finished records") { let past = card(.reminder,due:-60), future = card(.reminder,due:60); var a = archive([past,future]); try a.finish(past.id,at:date); try expect(a.notificationCards(at:date).map(\.id) == [future.id]) }
test("Notification plan caps 60 earliest future reminders") { let records = (1...70).reversed().map { card(.reminder,"\($0)",due:Double($0)*60) }; let plan = archive(records).notificationCards(at:date); try expect(plan.count == 60 && plan.first?.title == "1" && plan.last?.title == "60") }
test("Turkish search handles dotted and undotted letters") { try expect(Archive.folded("IŞIK İSTANBUL Çay") == "isik istanbul cay") }
test("Markdown keeps multiline body and normalizes title") { var c = card(); c.title = "one\ntwo"; c.body = "A\nB"; let output = archive([c]).markdown(); try expect(output.contains("## one two") && output.contains("A\nB")) }

let folder = FileManager.default.temporaryDirectory.appendingPathComponent("post-rules-"+UUID().uuidString)
defer { try? FileManager.default.removeItem(at:folder) }
test("Missing store starts empty") { try expect(try ArchiveStore(directory:folder).load().cards.isEmpty) }
test("Atomic store keeps previous version") { let store = ArchiveStore(directory:folder); let first = archive([card(.note,"Before")]), second = archive([card(.note,"After")]); try store.save(first); try store.save(second); try expect(try store.load() == second); try expect(try Archive.decode(Data(contentsOf:folder.appendingPathComponent("archive.previous.json"))) == first) }
test("Invalid candidate cannot overwrite valid file") { let store = ArchiveStore(directory:folder); let before = try Data(contentsOf:store.file); try rejects { try store.save(archive([card(.note,"")])) }; try expect(try Data(contentsOf:store.file) == before) }
test("Multiple notes and width survive save, edit, switch selection and fresh load") {
    let store = ArchiveStore(directory:folder.appendingPathComponent("multiple-notes"))
    var first = card(.note,"Alışveriş",scene:.home,pinned:true); first.ink = .rose; first.body = "Süt ve ekmek"
    let second = card(.note,"Yarın",scene:.pause)
    var a = archive([first,second]); a.settings.touchBarWidth = 280; a.settings.selectedCardID = first.id
    try store.save(a)
    var restored = try ArchiveStore(directory:store.directory).load()
    try expect(restored == a)
    var edit = restored.cards[1]; try edit.setMessageText("Yarın doktor randevusu"); edit.updatedAt = date.addingTimeInterval(60)
    try restored.put(edit); restored.settings.touchBarWidth = 560; restored.settings.selectedCardID = second.id
    try store.save(restored)
    let reopened = try ArchiveStore(directory:store.directory).load()
    try expect(reopened == restored && reopened.cards[0] == first && reopened.cards[1].id == second.id && reopened.settings.touchBarWidth == 560)
    try expect(try Archive.decode(Data(contentsOf:store.directory.appendingPathComponent("archive.previous.json"))) == a)
}
test("Invalid width save cannot erase notes, selected identity or previous valid archive") {
    let store = ArchiveStore(directory:folder.appendingPathComponent("invalid-width"))
    let first = card(.note,"Keep one",scene:.home,pinned:true), second = card(.note,"Keep two",scene:.pause)
    var a = archive([first,second]); a.settings.touchBarWidth = 320; a.settings.selectedCardID = second.id
    try store.save(a); a.settings.touchBarWidth = 480; try store.save(a)
    let before = try Data(contentsOf:store.file)
    let previousFile = store.directory.appendingPathComponent("archive.previous.json")
    let previous = try Data(contentsOf:previousFile)
    for width in [239,561] {
        var invalid = a; invalid.settings.touchBarWidth = width; invalid.cards.removeAll(); invalid.settings.selectedCardID = nil
        try rejects { try store.save(invalid) }
        try rejects { _ = try store.replace(with:invalid) }
        try expect(try Data(contentsOf:store.file) == before && Data(contentsOf:previousFile) == previous)
        try expect(try store.load() == a,"Rejected width changed persisted notes or their metadata")
    }
}
test("Corrupt original is never silently overwritten") { let store = ArchiveStore(directory:folder); let bad = Data("original-corrupt-record".utf8); try bad.write(to:store.file); try rejects { _ = try store.load() }; try rejects { try store.save(Archive()) }; try expect(try Data(contentsOf:store.file) == bad) }
test("Explicit replacement keeps raw recovery copy") { let store = ArchiveStore(directory:folder); let before = try Data(contentsOf:store.file); let recovery = try store.replace(with:Archive()); try expect(try Data(contentsOf:recovery) == before); try expect(try store.load().cards.isEmpty) }
test("Invalid replacement leaves original untouched") { let store = ArchiveStore(directory:folder); let before = try Data(contentsOf:store.file); try rejects { _ = try store.replace(with:archive([card(.note,"")])) }; try expect(try Data(contentsOf:store.file) == before) }
print("\(checked) core checks; \(failed) failures.")
exit(failed == 0 ? 0 : 1)
