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
test("Reminder requires date") { try rejects { _ = try archive([card(.reminder)]).validated() } }
test("Note cannot carry reminder date") { try rejects { _ = try archive([card(.note,due:60)]).validated() } }
test("Announcement cannot carry reminder date") { try rejects { _ = try archive([card(.announcement,due:60)]).validated() } }
test("Unknown archive version rejected") { var a = Archive(); a.version = 2; try rejects { _ = try a.validated() } }
test("Duplicate identities rejected") { let c = card(); try rejects { _ = try archive([c,c]).validated() } }
test("Capacity admits 200 and rejects 201") { _ = try archive((0..<200).map { card(.note,"\($0)") }).validated(); try rejects { _ = try archive((0..<201).map { card(.note,"\($0)") }).validated() } }
test("Nonfinite and out-of-range dates rejected") { var c = card(); c.createdAt = Date(timeIntervalSince1970:.infinity); try rejects { _ = try archive([c]).validated() }; c.createdAt = Date(timeIntervalSince1970:-1); try rejects { _ = try archive([c]).validated() } }
test("ISO backup roundtrip preserves content and settings") { var a = archive([card(.reminder,"Çay ☕",due:180)]); a.settings.privacy = true; a.settings.language = .en; try expect(try Archive.decode(a.encoded()) == a) }
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
test("Completion removes reminders from display and notifications") { let c = card(.reminder,due:60); var a = archive([c]); try a.finish(c.id,at:date); try expect(a.queue(at:date).isEmpty && a.notificationCards(at:date).isEmpty) }
test("Completion is idempotent") { let c = card(); var a = archive([c]); try a.finish(c.id,at:date); try a.finish(c.id,at:date.addingTimeInterval(9)); try expect(a.cards[0].doneAt == date) }
test("Restore preserves deadline and identity") { let c = card(.reminder,due:-60); var a = archive([c]); try a.finish(c.id,at:date); try a.restore(c.id,at:date); try expect(a.cards[0].id == c.id && a.cards[0].dueAt == c.dueAt && a.cards[0].isDue(at:date)) }
test("Snooze starts from current time") { let c = card(.reminder,due:-3600); var a = archive([c]); try a.snooze(c.id,minutes:5,at:date); try expect(a.cards[0].dueAt == date.addingTimeInterval(300) && !a.cards[0].isDue(at:date)) }
test("Invalid snooze leaves archive unchanged") { let c = card(.reminder,due:1); var a = archive([c]); let before = a; try rejects { try a.snooze(c.id,minutes:0,at:date) }; try expect(a == before); try rejects { try a.snooze(c.id,minutes:1441,at:date) } }
test("Cannot snooze notes or completed reminders") { let c = card(); var a = archive([c]); try rejects { try a.snooze(c.id,minutes:5,at:date) }; let r = card(.reminder,due:60); try a.put(r); try a.finish(r.id,at:date); try rejects { try a.snooze(r.id,minutes:5,at:date) } }
test("Editing replaces by identity") { var c = card(); var a = archive([c]); c.title = "Edited"; try a.put(c); try expect(a.cards.count == 1 && a.cards[0].title == "Edited") }
test("Invalid edit cannot partially mutate") { let c = card(); var a = archive([c]); var bad = c; bad.title = ""; try rejects { try a.put(bad) }; try expect(a.cards[0] == c) }
test("Deletion cancels notification plan") { let c = card(.reminder,due:60); var a = archive([c]); a.remove(c.id); try expect(a.notificationCards(at:date).isEmpty) }
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
