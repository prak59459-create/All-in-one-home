/// 四則演算の記号。
enum CalculatorOperation: String, CaseIterable, Sendable {
    case add = "+"
    case subtract = "−"
    case multiply = "×"
    case divide = "÷"

    /// VoiceOver で読み上げる名前。
    var spokenName: String {
        switch self {
        case .add: return "足す"
        case .subtract: return "引く"
        case .multiply: return "掛ける"
        case .divide: return "割る"
        }
    }

    var isAdditive: Bool {
        self == .add || self == .subtract
    }
}

/// 式の要素。数は打った形の文字列で持つ（"0." や "1.50" を、打った通りに表示するため）。
enum CalculatorToken: Hashable, Sendable {
    case number(String)
    case operation(CalculatorOperation)
    case openParen
    case closeParen

    var text: String {
        switch self {
        case .number(let literal): return literal
        case .operation(let operation): return operation.rawValue
        case .openParen: return "("
        case .closeParen: return ")"
        }
    }

    init?(text: String) {
        if let operation = CalculatorOperation(rawValue: text) {
            self = .operation(operation)
        } else if text == "(" {
            self = .openParen
        } else if text == ")" {
            self = .closeParen
        } else if DecimalText.isLiteral(text) {
            self = .number(text)
        } else {
            return nil
        }
    }
}

/// 保存形式: 要素ごとの文字列（"12"、"+"、"(" など）。
extension CalculatorToken: Codable {
    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let text: String = try container.decode(String.self)
        guard let token = CalculatorToken(text: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "式の要素が不正です: \(text)")
        }
        self = token
    }

    func encode(to encoder: Encoder) throws {
        var container: SingleValueEncodingContainer = encoder.singleValueContainer()
        try container.encode(text)
    }
}
