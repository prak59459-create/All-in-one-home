import Foundation

extension NoteBook {
    /// ピン留めを先に、その中は更新日時の新しい順（F0330、F0332）。
    var sortedNotes: [Note] {
        notes.sorted { (left: Note, right: Note) -> Bool in
            if left.isPinned != right.isPinned {
                return left.isPinned
            }
            if left.updatedAt != right.updatedAt {
                return left.updatedAt > right.updatedAt
            }
            return left.id < right.id
        }
    }

    /// 検索（F0325）。空白で区切った語がすべて、タイトルか本文に含まれるメモ。
    /// 大文字と小文字、全角と半角、アクセント記号の違いは区別しない。
    func search(_ query: String) -> [Note] {
        let terms: [String] = TextSearch.terms(in: query)
        guard !terms.isEmpty else { return sortedNotes }
        return sortedNotes.filter { (note: Note) -> Bool in
            TextSearch.matches(terms, in: [note.title, note.body])
        }
    }
}

/// メモ・タスクで共通の検索の規則。
enum TextSearch {
    static var options: String.CompareOptions {
        [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
    }

    static func terms(in query: String) -> [String] {
        query.split(whereSeparator: { (character: Character) -> Bool in character.isWhitespace })
            .map { (term: Substring) -> String in String(term) }
    }

    /// すべての語が、fields のどれかに含まれるか。
    static func matches(_ terms: [String], in fields: [String]) -> Bool {
        terms.allSatisfy { (term: String) -> Bool in
            fields.contains { (field: String) -> Bool in field.range(of: term, options: options) != nil }
        }
    }
}
