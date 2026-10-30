import Foundation

/// メモ1件（F0321–F0335）。
struct Note: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var title: String
    var body: String
    /// ピン留め（F0330）。一覧の先頭に出す。
    var isPinned: Bool
    let createdAt: Date
    var updatedAt: Date
}

enum NoteLimits {
    static let maximumCount: Int = 1000
    static let maximumTitleLength: Int = 200
    /// 400 字詰めの原稿用紙で 50 枚分。
    static let maximumBodyLength: Int = 20_000
}

enum NoteEditError: Error, Hashable, Sendable {
    case tooMany

    var message: String {
        switch self {
        case .tooMany: return "メモは \(NoteLimits.maximumCount) 件までです。使わないメモを削除してください。"
        }
    }
}

/// メモ帳（Apps/notes.json。F0353）。
struct NoteBook: MiniAppContent {
    static let fileID: String = "notes"
    static let formatVersion: Int = 1
    /// 上限いっぱいの件数・文字数でも読めるようにとる（実際の大きさは中身による）。
    static let maximumByteCount: Int = 32_000_000
    static let initial: NoteBook = NoteBook(notes: [])

    var notes: [Note]

    var problems: [String] {
        var found: [String] = []
        if notes.count > NoteLimits.maximumCount {
            found.append("メモが \(NoteLimits.maximumCount) 件を超えています。")
        }
        if Set(notes.map(\.id)).count != notes.count {
            found.append("同じ ID のメモがあります。")
        }
        let tooLong: Bool = notes.contains { (note: Note) -> Bool in
            note.title.count > NoteLimits.maximumTitleLength || note.body.count > NoteLimits.maximumBodyLength
        }
        if tooLong {
            found.append("長すぎるメモがあります。")
        }
        return found
    }

    static func newID() -> String {
        "note.\(UUID().uuidString.lowercased())"
    }

    func note(id: String) -> Note? {
        notes.first { (note: Note) -> Bool in note.id == id }
    }

    /// 空のメモを先頭に作る（F0321）。
    @discardableResult
    mutating func addNote(id: String, now: Date) throws -> Note {
        guard notes.count < NoteLimits.maximumCount else { throw NoteEditError.tooMany }
        let note = Note(id: id, title: "", body: "", isPinned: false, createdAt: now, updatedAt: now)
        notes.insert(note, at: 0)
        return note
    }

    /// タイトルと本文を変える（F0322、F0324）。上限を超えた分は切り詰める。変わった時だけ更新日時を進める（F0335）。
    mutating func updateNote(id: String, title: String, body: String, now: Date) {
        guard let index = notes.firstIndex(where: { (note: Note) -> Bool in note.id == id }) else { return }
        let newTitle: String = String(title.prefix(NoteLimits.maximumTitleLength))
        let newBody: String = String(body.prefix(NoteLimits.maximumBodyLength))
        guard notes[index].title != newTitle || notes[index].body != newBody else { return }
        notes[index].title = newTitle
        notes[index].body = newBody
        notes[index].updatedAt = now
    }

    mutating func setPinned(id: String, _ isPinned: Bool) {
        guard let index = notes.firstIndex(where: { (note: Note) -> Bool in note.id == id }) else { return }
        notes[index].isPinned = isPinned
    }

    mutating func removeNote(id: String) {
        notes.removeAll { (note: Note) -> Bool in note.id == id }
    }

    /// 何も書かずに閉じたメモは残さない（F0357）。
    mutating func removeIfEmpty(id: String) {
        guard let note = note(id: id), note.isEmpty else { return }
        removeNote(id: id)
    }
}

extension Note {
    /// 空白と改行だけのメモは空として扱う。
    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 一覧に出すタイトル。タイトルが空なら本文の最初の行。
    var displayTitle: String {
        let trimmed: String = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return Note.firstLine(of: body) ?? "新しいメモ"
    }

    /// 一覧でタイトルの下に出す1行。
    var preview: String {
        let hasTitle: Bool = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let lines: [String] = Note.nonEmptyLines(of: body)
        let rest: ArraySlice<String> = hasTitle ? lines[...] : lines.dropFirst()
        return rest.first ?? ""
    }

    private static func firstLine(of text: String) -> String? {
        nonEmptyLines(of: text).first
    }

    private static func nonEmptyLines(of text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { (line: Substring) -> String in line.trimmingCharacters(in: .whitespaces) }
            .filter { (line: String) -> Bool in !line.isEmpty }
    }
}
