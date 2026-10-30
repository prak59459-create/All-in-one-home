/// JSON の整形（F0511）。文字列と数は元の書き方のまま残し、空白と改行だけを入れ直す（キーの順も変えない）。
/// 読めない時は、何行目の何文字目が問題かを返す。
enum JSONFormatter {
    enum Style: Sendable {
        /// 2 文字ずつ字下げして、1 行に 1 つの値。
        case pretty
        /// 空白と改行をすべて除く。
        case compact
    }

    static let maximumDepth: Int = 100

    static func format(_ text: String, style: Style) -> Result<String, TextToolError> {
        var parser = JSONReformatter(bytes: Array(text.utf8), isPretty: style == .pretty)
        do {
            try parser.document()
            return .success(String(decoding: parser.output, as: UTF8.self))
        } catch let error as TextToolError {
            return .failure(error)
        } catch {
            return .failure(TextToolError(message: "JSON として読めません。"))
        }
    }
}

/// JSON を1文字ずつ読みながら、整形した形を書き出す。
private struct JSONReformatter {
    private enum Byte {
        static let openBrace: UInt8 = 0x7B
        static let closeBrace: UInt8 = 0x7D
        static let openBracket: UInt8 = 0x5B
        static let closeBracket: UInt8 = 0x5D
        static let quote: UInt8 = 0x22
        static let backslash: UInt8 = 0x5C
        static let colon: UInt8 = 0x3A
        static let comma: UInt8 = 0x2C
        static let minus: UInt8 = 0x2D
        static let plus: UInt8 = 0x2B
        static let dot: UInt8 = 0x2E
        static let newline: UInt8 = 0x0A
        static let space: UInt8 = 0x20
    }

    let bytes: [UInt8]
    let isPretty: Bool
    private var index: Int = 0
    private(set) var output: [UInt8] = []

    init(bytes: [UInt8], isPretty: Bool) {
        self.bytes = bytes
        self.isPretty = isPretty
    }

    mutating func document() throws {
        skipWhitespace()
        try value(depth: 0)
        skipWhitespace()
        guard index >= bytes.count else { throw failure("JSON の後に余分な文字があります。") }
    }

    private mutating func value(depth: Int) throws {
        guard depth <= JSONFormatter.maximumDepth else { throw failure("入れ子が深すぎます（\(JSONFormatter.maximumDepth) 段まで）。") }
        guard let byte = peek() else { throw failure("値がありません。") }
        switch byte {
        case Byte.openBrace:
            try container(close: Byte.closeBrace, depth: depth, isObject: true)
        case Byte.openBracket:
            try container(close: Byte.closeBracket, depth: depth, isObject: false)
        case Byte.quote:
            try string()
        case Byte.minus, 0x30...0x39:
            try number()
        case 0x74:
            try literal("true")
        case 0x66:
            try literal("false")
        case 0x6E:
            try literal("null")
        case 0x41...0x5A, 0x61...0x7A:
            throw failure("値として読めない文字があります（true・false・null は小文字で書き、文字列は「\"」で囲みます）。")
        default:
            throw failure("値として読めない文字があります。")
        }
    }

    /// オブジェクト（{"キー": 値, …}）と配列（[値, …]）。
    private mutating func container(close: UInt8, depth: Int, isObject: Bool) throws {
        let open: UInt8 = bytes[index]
        index += 1
        skipWhitespace()
        output.append(open)
        if peek() == close {
            index += 1
            output.append(close)
            return
        }
        while true {
            newline(depth: depth + 1)
            if isObject {
                try member(depth: depth)
            } else {
                try value(depth: depth + 1)
            }
            skipWhitespace()
            guard let next = peek() else { throw failure("「\(Character(Unicode.Scalar(close)))」で閉じられていません。") }
            index += 1
            if next == Byte.comma {
                output.append(Byte.comma)
                skipWhitespace()
                continue
            }
            guard next == close else { throw failure("「,」か「\(Character(Unicode.Scalar(close)))」が必要です。") }
            newline(depth: depth)
            output.append(close)
            return
        }
    }

    private mutating func member(depth: Int) throws {
        guard peek() == Byte.quote else { throw failure("キーは「\"」で囲んだ文字列にしてください。") }
        try string()
        skipWhitespace()
        guard peek() == Byte.colon else { throw failure("キーの後に「:」が必要です。") }
        index += 1
        output.append(Byte.colon)
        if isPretty {
            output.append(Byte.space)
        }
        skipWhitespace()
        try value(depth: depth + 1)
    }

    private mutating func string() throws {
        let start: Int = index
        index += 1
        while index < bytes.count {
            let byte: UInt8 = bytes[index]
            if byte == Byte.quote {
                index += 1
                output.append(contentsOf: bytes[start..<index])
                return
            }
            if byte == Byte.backslash {
                try escape()
                continue
            }
            guard byte >= 0x20 else { throw failure("文字列の中に改行やタブをそのまま入れることはできません（\\n や \\t と書きます）。") }
            index += 1
        }
        throw failure("文字列が「\"」で閉じられていません。")
    }

    private mutating func escape() throws {
        guard index + 1 < bytes.count else { throw failure("文字列が「\"」で閉じられていません。") }
        let escaped: UInt8 = bytes[index + 1]
        let simple: [UInt8] = [Byte.quote, Byte.backslash, 0x2F, 0x62, 0x66, 0x6E, 0x72, 0x74]
        if simple.contains(escaped) {
            index += 2
            return
        }
        guard escaped == 0x75 else { throw failure("使えない「\\」の組み合わせがあります。") }
        guard index + 5 < bytes.count, bytes[(index + 2)...(index + 5)].allSatisfy(JSONReformatter.isHex) else {
            throw failure("\\u の後は 16 進数 4 桁にしてください。")
        }
        index += 6
    }

    private mutating func number() throws {
        let start: Int = index
        if peek() == Byte.minus {
            index += 1
        }
        guard let first = peek(), JSONReformatter.isDigit(first) else { throw failure("数の形式が正しくありません。") }
        if first == 0x30 {
            index += 1
        } else {
            skipDigits()
        }
        if peek() == Byte.dot {
            index += 1
            try requireDigits()
        }
        if peek() == 0x65 || peek() == 0x45 {
            index += 1
            if peek() == Byte.plus || peek() == Byte.minus {
                index += 1
            }
            try requireDigits()
        }
        output.append(contentsOf: bytes[start..<index])
    }

    private mutating func requireDigits() throws {
        guard let next = peek(), JSONReformatter.isDigit(next) else { throw failure("数の形式が正しくありません。") }
        skipDigits()
    }

    private mutating func skipDigits() {
        while let next = peek(), JSONReformatter.isDigit(next) {
            index += 1
        }
    }

    private mutating func literal(_ word: String) throws {
        let expected: [UInt8] = Array(word.utf8)
        guard index + expected.count <= bytes.count, Array(bytes[index..<(index + expected.count)]) == expected else {
            throw failure("値として読めない文字があります（true・false・null は小文字で書きます）。")
        }
        index += expected.count
        output.append(contentsOf: expected)
    }

    private mutating func skipWhitespace() {
        while let next = peek(), next == Byte.space || next == Byte.newline || next == 0x09 || next == 0x0D {
            index += 1
        }
    }

    private mutating func newline(depth: Int) {
        guard isPretty else { return }
        output.append(Byte.newline)
        output.append(contentsOf: Array(repeating: Byte.space, count: depth * 2))
    }

    private func peek() -> UInt8? {
        index < bytes.count ? bytes[index] : nil
    }

    /// 問題の位置（行と列は 1 から。列は文字の数）を付けたエラー。
    private func failure(_ message: String) -> TextToolError {
        let end: Int = min(index, bytes.count)
        var line: Int = 1
        var column: Int = 1
        for byte in bytes[0..<end] {
            if byte == Byte.newline {
                line += 1
                column = 1
            } else if byte & 0xC0 != 0x80 {
                column += 1
            }
        }
        return TextToolError(message: "\(line) 行目の \(column) 文字目: \(message)")
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        (0x30...0x39).contains(byte)
    }

    private static func isHex(_ byte: UInt8) -> Bool {
        isDigit(byte) || (0x41...0x46).contains(byte) || (0x61...0x66).contains(byte)
    }
}
