import Foundation

public enum CardKind: String, Codable, CaseIterable { case announcement, note, reminder }
public enum Scene: String, Codable, CaseIterable { case desk, pause, home }
public enum Ink: String, Codable, CaseIterable { case amber, aqua, rose, lime }
public enum Language: String, Codable, CaseIterable { case tr, en }

public struct Settings: Codable, Equatable {
    public var scene: Scene = .desk
    public var privacy = false
    public var motion = true
    public var notifications = false
    public var language: Language = .tr
    public init() {}
}

public struct Card: Codable, Equatable, Identifiable {
    public var id: UUID
    public var kind: CardKind
    public var scene: Scene
    public var ink: Ink
    public var title: String
    public var body: String
    public var pinned: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var dueAt: Date?
    public var doneAt: Date?
    public init(id: UUID = UUID(), kind: CardKind, scene: Scene = .desk, ink: Ink = .amber,
                title: String, body: String = "", pinned: Bool = false, now: Date = Date(), dueAt: Date? = nil) {
        self.id = id; self.kind = kind; self.scene = scene; self.ink = ink
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pinned = pinned; createdAt = now; updatedAt = now; self.dueAt = dueAt; doneAt = nil
    }
    public func isDue(at now: Date) -> Bool { kind == .reminder && doneAt == nil && (dueAt.map { $0 <= now } ?? false) }
}

public enum PostError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}

public struct Archive: Codable, Equatable {
    public var version = 1
    public var settings = Settings()
    public var cards: [Card] = []
    public init() {}
    public func validated() throws -> Archive {
        guard version == 1 else { throw PostError.invalid("Unsupported archive version / Desteklenmeyen yedek sürümü.") }
        guard cards.count <= 200 else { throw PostError.invalid("Maximum 200 cards / En fazla 200 kart.") }
        guard Set(cards.map(\.id)).count == cards.count else { throw PostError.invalid("Duplicate card IDs / Tekrarlanan kart kimlikleri.") }
        for card in cards {
            guard !card.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  card.title.count <= 80, card.body.count <= 400 else {
                throw PostError.invalid("Title: 1–80 characters; body: 0–400 / Başlık: 1–80, metin: 0–400 karakter.")
            }
            guard (card.kind == .reminder) == (card.dueAt != nil) else {
                throw PostError.invalid("Only reminders require a date / Yalnızca hatırlatmalarda tarih bulunmalıdır.")
            }
            for date in [card.createdAt, card.updatedAt, card.dueAt, card.doneAt].compactMap({ $0 }) {
                guard date.timeIntervalSince1970.isFinite, (0...7_258_118_400).contains(date.timeIntervalSince1970) else {
                    throw PostError.invalid("Date outside 1970–2200 / Tarih 1970–2200 aralığında olmalıdır.")
                }
            }
        }
        return self
    }
    public func encoded() throws -> Data {
        _ = try validated()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
    public static func decode(_ data: Data) throws -> Archive {
        guard data.count <= 1_048_576 else { throw PostError.invalid("Backup exceeds 1 MB / Yedek 1 MB sınırını aşıyor.") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Archive.self, from: data).validated()
    }
    public mutating func put(_ card: Card) throws {
        var candidate = self
        if let index = candidate.cards.firstIndex(where: { $0.id == card.id }) { candidate.cards[index] = card }
        else { candidate.cards.append(card) }
        self = try candidate.validated()
    }
    public mutating func finish(_ id: UUID, at now: Date) throws {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { throw PostError.invalid("Card missing / Kart bulunamadı.") }
        guard cards[index].doneAt == nil else { return }
        var card = cards[index]; card.doneAt = now; card.updatedAt = now; try put(card)
    }
    public mutating func restore(_ id: UUID, at now: Date) throws {
        guard var card = cards.first(where: { $0.id == id }) else { throw PostError.invalid("Card missing / Kart bulunamadı.") }
        card.doneAt = nil; card.updatedAt = now; try put(card)
    }
    public mutating func snooze(_ id: UUID, minutes: Int, at now: Date) throws {
        guard (1...1440).contains(minutes), var card = cards.first(where: { $0.id == id }),
              card.kind == .reminder, card.doneAt == nil else { throw PostError.invalid("Cannot postpone this card / Bu kart ertelenemiyor.") }
        card.dueAt = now.addingTimeInterval(Double(minutes) * 60); card.updatedAt = now; try put(card)
    }
    public mutating func remove(_ id: UUID) { cards.removeAll { $0.id == id } }
    public func queue(at now: Date) -> [Card] {
        let pending = cards.filter { $0.doneAt == nil }
        let due = pending.filter { $0.isDue(at: now) }.sorted(by: Self.dueOrder)
        let dueIDs = Set(due.map(\.id))
        let scene = pending.filter { $0.scene == settings.scene && !dueIDs.contains($0.id) }.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        return due + scene
    }
    public func notificationCards(at now: Date) -> [Card] {
        Array(cards.filter { $0.kind == .reminder && $0.doneAt == nil && ($0.dueAt.map { $0 > now } ?? false) }
            .sorted(by: Self.dueOrder).prefix(60))
    }
    public static func dueOrder(_ a: Card, _ b: Card) -> Bool {
        if a.dueAt != b.dueAt { return (a.dueAt ?? .distantFuture) < (b.dueAt ?? .distantFuture) }
        return a.id.uuidString < b.id.uuidString
    }
    public func markdown() -> String {
        var lines = ["# Şerit · Touch Bar Post", "", "Personal export; dates are UTC / Kişisel dışa aktarım; tarihler UTC.", ""]
        let formatter = ISO8601DateFormatter()
        for card in cards {
            lines += ["## " + Self.oneLine(card.title), "", "- Kind: \(card.kind.rawValue) · Scene: \(card.scene.rawValue)",
                      "- State: \(card.doneAt == nil ? "active" : "done") · Pinned: \(card.pinned)"]
            if let due = card.dueAt { lines.append("- Reminder: " + formatter.string(from: due)) }
            lines += ["", card.body, ""]
        }
        return lines.joined(separator: "\n")
    }
    public static func oneLine(_ text: String) -> String { text.components(separatedBy: .newlines).joined(separator: " ") }
    public static func folded(_ text: String) -> String {
        text.replacingOccurrences(of: "ı", with: "i").replacingOccurrences(of: "İ", with: "i").replacingOccurrences(of: "I", with: "i")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}

/// The calling UI decides whether to keep working in memory after a failed write.
/// No file is overwritten until the entire candidate archive passes validation.
public final class ArchiveStore {
    public let directory: URL
    public var file: URL { directory.appendingPathComponent("archive.json") }
    public init(directory: URL) { self.directory = directory }
    public func load() throws -> Archive {
        guard FileManager.default.fileExists(atPath: file.path) else { return Archive() }
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= 1_048_576 else { throw PostError.invalid("Archive exceeds 1 MB / Kayıt 1 MB sınırını aşıyor.") }
        return try Archive.decode(Data(contentsOf: file))
    }
    public func save(_ archive: Archive) throws {
        let data = try archive.encoded()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: file.path) {
            let previous = try Data(contentsOf: file)
            _ = try Archive.decode(previous)
            try previous.write(to: directory.appendingPathComponent("archive.previous.json"), options: .atomic)
        }
        try data.write(to: file, options: .atomic)
    }
    @discardableResult public func recoveryCopy() throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let output = directory.appendingPathComponent("archive.recovery-\(UUID().uuidString).json")
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.copyItem(at: file, to: output) }
        return output
    }
    @discardableResult public func replace(with archive: Archive) throws -> URL {
        let data = try archive.encoded()
        let recovery = try recoveryCopy()
        try data.write(to: file, options: .atomic)
        return recovery
    }
}
