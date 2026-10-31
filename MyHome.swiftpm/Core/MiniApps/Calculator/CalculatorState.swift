import Foundation

/// 計算の履歴1件。
struct CalculationRecord: Identifiable, Hashable, Codable, Sendable {
    let id: String
    /// 計算した式（表示の形）。
    let expression: String
    /// 結果（保存用の形。丸めていない）。
    let result: String
    let date: Date
}

/// 電卓（Apps/calculator.json。F0504）。入力中の式・直前の結果・履歴を保存し、開き直しても続きから使える。
struct CalculatorState: MiniAppContent {
    static let fileID: String = "calculator"
    static let formatVersion: Int = 1
    static let maximumByteCount: Int = 1_000_000
    static let initial: CalculatorState = CalculatorState(tokens: [], lastResult: nil, history: [])
    static let maximumTokens: Int = 200
    static let maximumHistory: Int = 50

    var tokens: [CalculatorToken]
    /// 直前の「=」の結果（保存用の形）。式が空の時に表示し、演算子を押すと続けて計算する。
    var lastResult: String?
    /// 新しい順。
    var history: [CalculationRecord]

    var problems: [String] {
        var found: [String] = []
        if tokens.count > CalculatorState.maximumTokens {
            found.append("式が長すぎます。")
        }
        if history.count > CalculatorState.maximumHistory {
            found.append("履歴が多すぎます。")
        }
        if let lastResult, !DecimalText.isLiteral(lastResult) {
            found.append("直前の結果の形式が不正です。")
        }
        let badRecord: Bool = history.contains { (record: CalculationRecord) -> Bool in
            !DecimalText.isLiteral(record.result) || record.expression.count > 10_000
        }
        if badRecord {
            found.append("履歴の形式が不正です。")
        }
        return found
    }

    /// 大きく表示する内容。式が空なら直前の結果（なければ 0）。
    var mainText: String {
        if tokens.isEmpty {
            return lastResult.flatMap(DecimalText.parse).map(DecimalText.display) ?? "0"
        }
        return CalculatorState.expressionText(tokens)
    }

    /// 入力中の式の途中結果（演算子を含む時だけ）。
    var previewText: String? {
        guard tokens.contains(where: CalculatorEvaluator.isOperation) else { return nil }
        guard case .success(let value) = CalculatorEvaluator.evaluate(tokens) else { return nil }
        return DecimalText.display(value)
    }

    /// "12 + 3 × (4 − 1)" の形。
    static func expressionText(_ tokens: [CalculatorToken]) -> String {
        var text: String = ""
        for token in tokens {
            switch token {
            case .number(let literal):
                text += DecimalText.displayLiteral(literal)
            case .operation(let operation):
                text += " \(operation.rawValue) "
            case .openParen, .closeParen:
                text += token.text
            }
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    /// 「=」。計算できたら履歴に加え、結果を表示する。計算できない時は式を残して理由を返す。
    mutating func evaluate(now: Date, id: String) -> CalculatorError? {
        guard !tokens.isEmpty else { return nil }
        switch CalculatorEvaluator.evaluate(tokens) {
        case .success(let value):
            let result: String = DecimalText.canonical(value)
            let record = CalculationRecord(id: id, expression: CalculatorState.expressionText(tokens), result: result, date: now)
            history.insert(record, at: 0)
            if history.count > CalculatorState.maximumHistory {
                history.removeLast(history.count - CalculatorState.maximumHistory)
            }
            lastResult = result
            tokens = []
            return nil
        case .failure(let error):
            return error
        }
    }

    /// 履歴の結果を、次の計算に使う。
    mutating func reuse(_ record: CalculationRecord) {
        tokens = []
        lastResult = record.result
    }

    mutating func clearHistory() {
        history = []
    }

    static func newRecordID() -> String {
        "calc.\(UUID().uuidString.lowercased())"
    }
}
