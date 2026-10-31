import Foundation

/// Qwen2.5 のトークナイザー（バイト単位の BPE。追加フェーズ A の Core ML の Qwen 用）。vocab.json と merges.txt から作る。
/// Hugging Face の tokenizers と同じ手順: NFC で正規化 → 正規表現で区切る → UTF-8 のバイトを文字に置き換える → 結合の順位で BPE。
/// 特別なトークン（<|im_start|> など）は文字列からは作らない（利用者の文に書かれていても、普通の文字として扱う）。
/// 会話の形にする時は QwenPrompt が ID を直接入れる。
/// 持っている値は作った後に変えない。NSRegularExpression も作った後は変わらず、どのスレッドから使ってもよい（Apple の説明のとおり）。
final class QwenTokenizer: @unchecked Sendable {
    static let endOfText: Int = 151_643
    static let imStart: Int = 151_644
    static let imEnd: Int = 151_645
    /// これ以上の ID は特別なトークン（文字としては出さない）。
    static let firstSpecial: Int = 151_643

    /// Qwen2 の区切り方（tokenizer.json の pre_tokenizer と同じ）。
    static let pattern: String = #"(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+"#

    private let encoder: [String: Int]
    private let decoder: [Int: String]
    private let ranks: [String: Int]
    private let splitter: NSRegularExpression
    private let byteToSymbol: [String]
    private let symbolToByte: [Unicode.Scalar: UInt8]

    init(vocabJSON: Data, merges: String) throws {
        guard let raw = try JSONSerialization.jsonObject(with: vocabJSON) as? [String: Int] else {
            throw QwenTokenizerError.unreadableVocabulary
        }
        encoder = raw
        var reverse: [Int: String] = [:]
        reverse.reserveCapacity(raw.count)
        for (token, id) in raw {
            reverse[id] = token
        }
        decoder = reverse
        ranks = QwenTokenizer.parseMerges(merges)
        guard !ranks.isEmpty else { throw QwenTokenizerError.unreadableMerges }
        splitter = try NSRegularExpression(pattern: QwenTokenizer.pattern)
        let table: [Unicode.Scalar] = QwenTokenizer.byteTable()
        byteToSymbol = table.map { (scalar: Unicode.Scalar) -> String in String(scalar) }
        var back: [Unicode.Scalar: UInt8] = [:]
        for (byte, scalar) in table.enumerated() {
            back[scalar] = UInt8(byte)
        }
        symbolToByte = back
    }

    /// フォルダの vocab.json と merges.txt から作る。
    convenience init(directory: URL) throws {
        let vocab: Data = try Data(contentsOf: directory.appendingPathComponent("vocab.json"))
        let merges: String = try String(contentsOf: directory.appendingPathComponent("merges.txt"), encoding: .utf8)
        try self.init(vocabJSON: vocab, merges: merges)
    }

    var vocabularySize: Int {
        encoder.count
    }

    /// 文字列を ID にする（特別なトークンは作らない）。
    func encode(_ text: String) -> [Int] {
        let normalized: String = text.precomposedStringWithCanonicalMapping
        var ids: [Int] = []
        for piece in split(normalized) {
            let symbols: [String] = Array(piece.utf8).map { (byte: UInt8) -> String in byteToSymbol[Int(byte)] }
            for token in bpe(symbols) {
                if let id = encoder[token] {
                    ids.append(id)
                }
            }
        }
        return ids
    }

    /// ID を文字列にする。特別なトークンは出さない。途中で切れた UTF-8 は置き換え文字になる。
    func decode(_ ids: [Int]) -> String {
        String(decoding: bytes(for: ids), as: UTF8.self)
    }

    /// ID のバイト列（特別なトークンは空）。少しずつ表示する時は QwenStreamDecoder に渡す。
    func bytes(for ids: [Int]) -> [UInt8] {
        var result: [UInt8] = []
        for id in ids where id < QwenTokenizer.firstSpecial {
            guard let token = decoder[id] else { continue }
            for scalar in token.unicodeScalars {
                if let byte = symbolToByte[scalar] {
                    result.append(byte)
                }
            }
        }
        return result
    }

    // MARK: - 内部

    private func split(_ text: String) -> [String] {
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        return splitter.matches(in: text, range: whole).compactMap { (match: NSTextCheckingResult) -> String? in
            Range(match.range, in: text).map { (range: Range<String.Index>) -> String in String(text[range]) }
        }
    }

    /// 一番順位の高い（数の小さい）隣り合う組を、なくなるまで結合する（GPT-2 と同じ手順）。
    private func bpe(_ symbols: [String]) -> [String] {
        var word: [String] = symbols
        while word.count > 1 {
            guard let (first, second) = bestPair(in: word) else { break }
            word = merge(word, first: first, second: second)
        }
        return word
    }

    private func bestPair(in word: [String]) -> (String, String)? {
        var bestRank: Int = .max
        var best: (String, String)?
        for index in 0..<(word.count - 1) {
            if let rank = ranks[word[index] + " " + word[index + 1]], rank < bestRank {
                bestRank = rank
                best = (word[index], word[index + 1])
            }
        }
        return best
    }

    private func merge(_ word: [String], first: String, second: String) -> [String] {
        var merged: [String] = []
        merged.reserveCapacity(word.count)
        var index: Int = 0
        while index < word.count {
            if index < word.count - 1, word[index] == first, word[index + 1] == second {
                merged.append(first + second)
                index += 2
            } else {
                merged.append(word[index])
                index += 1
            }
        }
        return merged
    }

    private static func parseMerges(_ text: String) -> [String: Int] {
        var ranks: [String: Int] = [:]
        var rank: Int = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("#version") {
                continue
            }
            let parts: [Substring] = line.split(separator: " ")
            guard parts.count == 2 else { continue }
            ranks[parts[0] + " " + parts[1]] = rank
            rank += 1
        }
        return ranks
    }

    /// GPT-2 のバイト → 文字の表（印刷できるバイトはそのままの文字、それ以外は U+0100 から順に割り当てる）。
    private static func byteTable() -> [Unicode.Scalar] {
        var printable: [Int] = Array(33...126) + Array(161...172) + Array(174...255)
        var scalars: [Int] = printable
        var next: Int = 0
        for byte in 0..<256 where !printable.contains(byte) {
            printable.append(byte)
            scalars.append(256 + next)
            next += 1
        }
        var table: [Unicode.Scalar] = Array(repeating: " ", count: 256)
        for (byte, scalar) in zip(printable, scalars) {
            table[byte] = Unicode.Scalar(UInt32(scalar)) ?? " "
        }
        return table
    }
}

enum QwenTokenizerError: Error, Hashable, Sendable {
    case unreadableVocabulary
    case unreadableMerges
}

/// 生成したトークンを少しずつ文字にする。UTF-8 の途中で切れたバイトは、続きが来るまで持っておく。
struct QwenStreamDecoder: Sendable {
    private var pending: [UInt8] = []

    /// 新しく確定した文字列を返す。
    mutating func append(_ bytes: [UInt8]) -> String {
        pending.append(contentsOf: bytes)
        let complete: Int = QwenStreamDecoder.completeLength(pending)
        let text: String = String(decoding: pending[..<complete], as: UTF8.self)
        pending.removeFirst(complete)
        return text
    }

    /// 残り（最後に足りなかったバイトは置き換え文字になる）。
    mutating func finish() -> String {
        let text: String = String(decoding: pending, as: UTF8.self)
        pending.removeAll()
        return text
    }

    /// 末尾の、まだ続きが来るはずの UTF-8 の途中（最大 3 バイト）を除いた長さ。
    static func completeLength(_ bytes: [UInt8]) -> Int {
        var start: Int = bytes.count
        var checked: Int = 0
        while start > 0, checked < 4 {
            let byte: UInt8 = bytes[start - 1]
            if byte & 0xC0 == 0x80 {
                start -= 1
                checked += 1
                continue
            }
            let needed: Int = byte >= 0xF0 ? 4 : byte >= 0xE0 ? 3 : byte >= 0xC0 ? 2 : 1
            let available: Int = bytes.count - (start - 1)
            return available >= needed ? bytes.count : start - 1
        }
        return bytes.count
    }
}
