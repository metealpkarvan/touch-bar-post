import Foundation
import PostCore

var checked = 0, failed = 0
let date = Date(timeIntervalSince1970:1_791_180_000)
func test(_ title:String,_ body:() throws -> Void) { checked += 1; do { try body(); print("PASS \(title)") } catch { failed += 1; print("FAIL \(title): \(error)") } }
func expect(_ value:@autoclosure () throws -> Bool,_ message:String = "Unexpected result") throws { if try !value() { throw PostError.invalid(message) } }
func rejects(_ body:() throws -> Void) throws { var rejected = false; do { try body() } catch { rejected = true }; try expect(rejected,"Expected rejection") }
func card(_ kind:CardKind = .note,_ title:String = "Not",scene:Scene = .desk,pinned:Bool = false,due:Double? = nil) -> Card { Card(kind:kind,scene:scene,title:title,pinned:pinned,now:date,dueAt:due.map { date.addingTimeInterval($0) }) }
func archive(_ cards:[Card]) -> Archive { var value = Archive(); value.cards = cards; return value }

test("Empty archive and privacy defaults") { let a = try Archive().validated(); try expect(a.cards.isEmpty && !a.settings.notifications && !a.settings.privacy && a.settings.scene == .desk) }
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
    try expect(a.version == 1 && a.settings.scene == .pause && a.settings.privacy && !a.settings.motion && a.settings.notifications && a.settings.language == .en && a.settings.selectedCardID == nil)
    try expect(a.cards[0].scene == .home && a.cards[0].ink == .rose && a.cards[0].pinned && a.cards[0].body == "Line one\nLine two")
    try expect(a.cards[2].doneAt != nil && a.queue(at:date).isEmpty)
    try expect(a.simpleQueue(at:date).map(\.title) == ["Old home note","Old deadline"])
    try expect(try Archive.decode(a.encoded()) == a,"Simplification changed the existing archive format")
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
test("Corrupt original is never silently overwritten") { let store = ArchiveStore(directory:folder); let bad = Data("original-corrupt-record".utf8); try bad.write(to:store.file); try rejects { _ = try store.load() }; try rejects { try store.save(Archive()) }; try expect(try Data(contentsOf:store.file) == bad) }
test("Explicit replacement keeps raw recovery copy") { let store = ArchiveStore(directory:folder); let before = try Data(contentsOf:store.file); let recovery = try store.replace(with:Archive()); try expect(try Data(contentsOf:recovery) == before); try expect(try store.load().cards.isEmpty) }
test("Invalid replacement leaves original untouched") { let store = ArchiveStore(directory:folder); let before = try Data(contentsOf:store.file); try rejects { _ = try store.replace(with:archive([card(.note,"")])) }; try expect(try Data(contentsOf:store.file) == before) }
print("\(checked) core checks; \(failed) failures.")
exit(failed == 0 ? 0 : 1)
