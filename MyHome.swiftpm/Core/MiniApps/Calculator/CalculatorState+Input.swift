import Foundation

/// 電卓のキー（「=」は履歴を作るので CalculatorState.evaluate で扱う）。
enum CalculatorKey: Hashable, Sendable {
    case digit(Int)
    case decimalPoint
    case operation(CalculatorOperation)
    case openParen
    case closeParen
    /// 今の数の符号を変える（±）。
    case toggleSign
    /// 今の数を 100 で割る（%）。
    case percent
    /// 1 文字消す（⌫）。
    case backspace
    /// 式と直前の結果を消す（C）。履歴は残す。
    case clear
}

extension CalculatorState {
    /// キーを1つ押す。押せない場面（閉じるかっこがないのに「)」など）では何もしない。
    mutating func press(_ key: CalculatorKey) {
        switch key {
        case .digit(let digit):
            appendDigit(digit)
        case .decimalPoint:
            appendDecimalPoint()
        case .operation(let operation):
            appendOperation(operation)
        case .openParen:
            appendOpenParen()
        case .closeParen:
            appendCloseParen()
        case .toggleSign:
            toggleSign()
        case .percent:
            applyPercent()
        case .backspace:
            backspace()
        case .clear:
            tokens = []
            lastResult = nil
        }
    }

    private var lastNumber: String? {
        guard case .number(let literal)? = tokens.last else { return nil }
        return literal
    }

    private mutating func replaceLastNumber(with literal: String) {
        tokens[tokens.count - 1] = .number(literal)
    }

    private mutating func append(_ newTokens: [CalculatorToken]) {
        guard tokens.count + newTokens.count <= CalculatorState.maximumTokens else { return }
        tokens.append(contentsOf: newTokens)
    }

    /// 数の直後に「(」や数を続ける時は、間に「×」を入れる（2(3) = 6）。
    private var needsImplicitMultiplication: Bool {
        tokens.last == .closeParen
    }

    private mutating func startNewCalculationIfNeeded() {
        if tokens.isEmpty {
            lastResult = nil
        }
    }

    private mutating func appendDigit(_ digit: Int) {
        guard (0...9).contains(digit) else { return }
        startNewCalculationIfNeeded()
        if let literal = lastNumber {
            guard DecimalText.digitCount(literal) < DecimalText.significantDigits else { return }
            switch literal {
            case "0": replaceLastNumber(with: "\(digit)")
            case "-0": replaceLastNumber(with: "-\(digit)")
            default: replaceLastNumber(with: literal + "\(digit)")
            }
            return
        }
        let prefix: [CalculatorToken] = needsImplicitMultiplication ? [.operation(.multiply)] : []
        append(prefix + [.number("\(digit)")])
    }

    private mutating func appendDecimalPoint() {
        startNewCalculationIfNeeded()
        if let literal = lastNumber {
            guard !literal.contains("."), DecimalText.digitCount(literal) < DecimalText.significantDigits else { return }
            replaceLastNumber(with: literal + ".")
            return
        }
        let prefix: [CalculatorToken] = needsImplicitMultiplication ? [.operation(.multiply)] : []
        append(prefix + [.number("0.")])
    }

    private mutating func appendOperation(_ operation: CalculatorOperation) {
        if tokens.isEmpty {
            // 「=」の後に演算子を押したら、その結果から続ける
            tokens = [.number(lastResult ?? "0")]
        }
        switch tokens.last {
        case .operation?:
            tokens[tokens.count - 1] = .operation(operation)
        case .openParen?:
            // 「(」の直後の「−」は負の数の始まり
            if operation == .subtract {
                append([.number("-0")])
            }
        default:
            append([.operation(operation)])
        }
    }

    private mutating func appendOpenParen() {
        startNewCalculationIfNeeded()
        if lastNumber != nil || needsImplicitMultiplication {
            append([.operation(.multiply), .openParen])
        } else {
            append([.openParen])
        }
    }

    private mutating func appendCloseParen() {
        let open: Int = tokens.filter { (token: CalculatorToken) -> Bool in token == .openParen }.count
        let close: Int = tokens.filter { (token: CalculatorToken) -> Bool in token == .closeParen }.count
        guard open > close, lastNumber != nil || tokens.last == .closeParen else { return }
        append([.closeParen])
    }

    private mutating func toggleSign() {
        if tokens.isEmpty {
            tokens = [.number(CalculatorState.negated(lastResult ?? "0"))]
            return
        }
        if let literal = lastNumber {
            replaceLastNumber(with: CalculatorState.negated(literal))
        } else if tokens.last != .closeParen {
            append([.number("-0")])
        }
    }

    private mutating func applyPercent() {
        if tokens.isEmpty, let lastResult {
            tokens = [.number(lastResult)]
        }
        guard let literal = lastNumber, let value = DecimalText.parse(literal) else { return }
        replaceLastNumber(with: DecimalText.canonical(value / 100))
    }

    private mutating func backspace() {
        guard let last = tokens.popLast() else {
            lastResult = nil
            return
        }
        guard case .number(let literal) = last else { return }
        var shortened: String = literal
        if DecimalText.digitCount(shortened) > DecimalText.significantDigits, let value = DecimalText.parse(shortened) {
            // 計算結果を続けて使っている長い数は、表示している桁に丸めてから消す
            shortened = DecimalText.canonical(DecimalText.rounded(value))
        }
        shortened.removeLast()
        if !shortened.isEmpty && shortened != "-" {
            tokens.append(.number(shortened))
        }
    }

    private static func negated(_ literal: String) -> String {
        literal.hasPrefix("-") ? String(literal.dropFirst()) : "-" + literal
    }
}
