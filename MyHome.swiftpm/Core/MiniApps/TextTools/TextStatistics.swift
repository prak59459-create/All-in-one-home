/// 文字数などの数（F0514）。文字は見た目の1文字（絵文字や「が」の濁点の組み合わせも1文字）で数える。
struct TextStatistics: Hashable, Sendable {
    let characters: Int
    /// 空白・改行を除いた文字数。
    let charactersExcludingWhitespace: Int
    /// 行数（空の文章は 0。最後が改行なら、その後の空の行も数える）。
    let lines: Int
    /// 空でない行の数。
    let nonEmptyLines: Int
    /// 空白で区切った語の数（日本語の文は区切りがないので、英文などの目安）。
    let words: Int
    /// UTF-8 で保存した時のバイト数。
    let utf8Bytes: Int
    /// 400 字詰めの原稿用紙の枚数の目安（改行を除いた文字数を 400 で割って切り上げ。禁則や行末の空きは考えない）。
    let manuscriptPages: Int

    init(_ text: String) {
        characters = text.count
        charactersExcludingWhitespace = text.filter { (character: Character) -> Bool in !character.isWhitespace }.count
        let lineList: [Substring] = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        lines = text.isEmpty ? 0 : lineList.count
        nonEmptyLines = lineList.filter { (line: Substring) -> Bool in
            !line.allSatisfy { (character: Character) -> Bool in character.isWhitespace }
        }.count
        words = text.split(whereSeparator: { (character: Character) -> Bool in character.isWhitespace }).count
        utf8Bytes = text.utf8.count
        let withoutNewlines: Int = text.filter { (character: Character) -> Bool in !character.isNewline }.count
        manuscriptPages = (withoutNewlines + 399) / 400
    }
}
