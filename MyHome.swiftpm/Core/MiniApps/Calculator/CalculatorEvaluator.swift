import Foundation

enum CalculatorError: Error, Hashable, Sendable {
    case divisionByZero
    case outOfRange
    case malformed

    var message: String {
        switch self {
        case .divisionByZero: return "0 で割ることはできません。"
        case .outOfRange: return "計算できる範囲を超えました。"
        case .malformed: return "式が正しくありません。"
        }
    }
}

/// 式の計算。掛け算・割り算を先に計算し（2 + 3 × 4 = 14）、かっこの中をさらに先に計算する。
/// 末尾の演算子は無視し、閉じていないかっこは最後に閉じたものとして計算する。
enum CalculatorEvaluator {
    static func evaluate(_ tokens: [CalculatorToken]) -> Result<Decimal, CalculatorError> {
        var parser = Parser(tokens: completed(tokens))
        do {
            let value: Decimal = try parser.expression()
            guard parser.isAtEnd else { return .failure(.malformed) }
            return .success(value)
        } catch let error as CalculatorError {
            return .failure(error)
        } catch {
            return .failure(.malformed)
        }
    }

    /// 末尾の演算子と開きかっこを除き、足りない閉じかっこを補う。
    static func completed(_ tokens: [CalculatorToken]) -> [CalculatorToken] {
        var result: [CalculatorToken] = tokens
        while let last = result.last, last == .openParen || CalculatorEvaluator.isOperation(last) {
            result.removeLast()
        }
        let open: Int = result.filter { (token: CalculatorToken) -> Bool in token == .openParen }.count
        let close: Int = result.filter { (token: CalculatorToken) -> Bool in token == .closeParen }.count
        if open > close {
            result.append(contentsOf: Array(repeating: CalculatorToken.closeParen, count: open - close))
        }
        return result
    }

    static func isOperation(_ token: CalculatorToken) -> Bool {
        if case .operation = token {
            return true
        }
        return false
    }

    private struct Parser {
        let tokens: [CalculatorToken]
        var position: Int = 0

        var isAtEnd: Bool {
            position >= tokens.count
        }

        mutating func expression() throws -> Decimal {
            var value: Decimal = try term()
            while let operation = peekOperation(), operation.isAdditive {
                position += 1
                let right: Decimal = try term()
                value = try CalculatorEvaluator.apply(operation, value, right)
            }
            return value
        }

        mutating func term() throws -> Decimal {
            var value: Decimal = try factor()
            while let operation = peekOperation(), !operation.isAdditive {
                position += 1
                let right: Decimal = try factor()
                value = try CalculatorEvaluator.apply(operation, value, right)
            }
            return value
        }

        mutating func factor() throws -> Decimal {
            guard !isAtEnd else { throw CalculatorError.malformed }
            switch tokens[position] {
            case .number(let literal):
                position += 1
                guard let value = DecimalText.parse(literal) else { throw CalculatorError.malformed }
                return value
            case .openParen:
                position += 1
                let value: Decimal = try expression()
                guard !isAtEnd, tokens[position] == .closeParen else { throw CalculatorError.malformed }
                position += 1
                return value
            case .operation, .closeParen:
                throw CalculatorError.malformed
            }
        }

        private func peekOperation() -> CalculatorOperation? {
            guard !isAtEnd, case .operation(let operation) = tokens[position] else { return nil }
            return operation
        }
    }

    private static func apply(_ operation: CalculatorOperation, _ left: Decimal, _ right: Decimal) throws -> Decimal {
        let result: Decimal
        switch operation {
        case .add:
            result = left + right
        case .subtract:
            result = left - right
        case .multiply:
            result = left * right
        case .divide:
            guard !right.isZero else { throw CalculatorError.divisionByZero }
            result = left / right
        }
        guard !result.isNaN else { throw CalculatorError.outOfRange }
        return result
    }
}
