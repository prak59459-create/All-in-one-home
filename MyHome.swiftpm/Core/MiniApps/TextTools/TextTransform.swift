import Foundation

/// 文章の整形（F0512）。改行は「\n」にそろえる。
enum TextTransform: String, CaseIterable, Identifiable, Sendable {
    case trimLines
    case removeEmptyLines
    case removeDuplicateLines
    case sortLines
    case joinLines
    case toHalfWidth
    case toFullWidth
    case uppercase
    case lowercase

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trimLines: return "各行の前後の空白を削除"
        case .removeEmptyLines: return "空の行を削除"
        case .removeDuplicateLines: return "重複した行を削除"
        case .sortLines: return "行を並べ替え"
        case .joinLines: return "改行を削除して1行に"
        case .toHalfWidth: return "英数字・記号を半角に"
        case .toFullWidth: return "英数字・記号を全角に"
        case .uppercase: return "英字を大文字に"
        case .lowercase: return "英字を小文字に"
        }
    }

    func apply(_ text: String) -> String {
        switch self {
        case .trimLines:
            return TextTransform.mapLines(text) { (line: String) -> String in line.trimmingCharacters(in: .whitespaces) }
        case .removeEmptyLines:
            return TextTransform.lines(of: text).filter { (line: String) -> Bool in
                !line.allSatisfy { (character: Character) -> Bool in character.isWhitespace }
            }.joined(separator: "\n")
        case .removeDuplicateLines:
            return TextTransform.uniqueLines(text)
        case .sortLines:
            return TextTransform.lines(of: text).sorted(by: TextTransform.isOrderedBefore).joined(separator: "\n")
        case .joinLines:
            return TextTransform.lines(of: text).joined()
        case .toHalfWidth:
            return TextWidth.toHalfWidth(text)
        case .toFullWidth:
            return TextWidth.toFullWidth(text)
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        }
    }

    static func lines(of text: String) -> [String] {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map { (line: Substring) -> String in String(line) }
    }

    private static func mapLines(_ text: String, _ transform: (String) -> String) -> String {
        lines(of: text).map(transform).joined(separator: "\n")
    }

    /// 最初に出てきた行を残す。
    private static func uniqueLines(_ text: String) -> String {
        var seen: Set<String> = []
        var kept: [String] = []
        for line in lines(of: text) where seen.insert(line).inserted {
            kept.append(line)
        }
        return kept.joined(separator: "\n")
    }

    /// 数字は数の大きさで比べる（"2" が "10" より前）。大文字と小文字、全角と半角は区別しない。
    private static func isOrderedBefore(_ left: String, _ right: String) -> Bool {
        let order: ComparisonResult = left.compare(right, options: [.numeric, .caseInsensitive, .widthInsensitive])
        if order != .orderedSame {
            return order == .orderedAscending
        }
        return left < right
    }
}
