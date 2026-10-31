import Foundation
import XCTest
@testable import MyHomeCore

/// T5-4: 電卓（入力の規則、優先順位、10 進数での計算、表示の形、履歴）。
final class CalculatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    /// キーの並びを押す。~ は ±、< は ⌫、C はクリア。
    private func press(_ keys: String, on state: inout CalculatorState) {
        for character in keys {
            switch character {
            case "0"..."9":
                state.press(.digit(Int(String(character)) ?? 0))
            case ".": state.press(.decimalPoint)
            case "+": state.press(.operation(.add))
            case "-": state.press(.operation(.subtract))
            case "*": state.press(.operation(.multiply))
            case "/": state.press(.operation(.divide))
            case "(": state.press(.openParen)
            case ")": state.press(.closeParen)
            case "~": state.press(.toggleSign)
            case "%": state.press(.percent)
            case "<": state.press(.backspace)
            case "C": state.press(.clear)
            default: XCTFail("テストのキーが不正: \(character)")
            }
        }
    }

    /// キーを押して「=」を押した後の表示。
    private func result(of keys: String) -> String {
        var state: CalculatorState = .initial
        press(keys, on: &state)
        if let error = state.evaluate(now: now, id: "r") {
            return error.message
        }
        return state.mainText
    }

    func testPrecedenceAndParentheses() {
        XCTAssertEqual(result(of: "2+3*4"), "14")
        XCTAssertEqual(result(of: "(2+3)*4"), "20")
        XCTAssertEqual(result(of: "2(3+4)"), "14", "かっこの前の数とは掛け算")
        XCTAssertEqual(result(of: "(1+2)(3+4)"), "21")
        XCTAssertEqual(result(of: "10-2-3"), "5", "左から順に計算する")
        XCTAssertEqual(result(of: "8/2/2"), "2")
        XCTAssertEqual(result(of: "2*(3+4"), "14", "閉じていないかっこは最後に閉じる")
        XCTAssertEqual(result(of: "2+3*"), "5", "末尾の演算子は無視する")
    }

    func testDecimalArithmeticIsExact() {
        XCTAssertEqual(result(of: "0.1+0.2"), "0.3")
        XCTAssertEqual(result(of: "1.1*1.1"), "1.21")
        XCTAssertEqual(result(of: "1/3"), "0.333333333333333", "15 桁に丸めて表示する")
        XCTAssertEqual(result(of: "1/3*3"), "1")
        XCTAssertEqual(result(of: "1234567*1000"), "1,234,567,000")
    }

    func testErrorsKeepTheExpression() {
        var state: CalculatorState = .initial
        press("5/0", on: &state)
        XCTAssertEqual(state.evaluate(now: now, id: "r"), .divisionByZero)
        XCTAssertEqual(state.mainText, "5 ÷ 0", "直せるように式を残す")
        XCTAssertTrue(state.history.isEmpty)

        var huge: CalculatorState = .initial
        for _ in 0..<12 {
            press("999999999999999*", on: &huge)
        }
        press("9", on: &huge)
        XCTAssertEqual(huge.evaluate(now: now, id: "r"), .outOfRange)
    }

    func testOperatorsReplaceAndContinueFromResult() {
        var state: CalculatorState = .initial
        press("5+*3", on: &state)
        XCTAssertEqual(state.mainText, "5 × 3", "続けて押した演算子は置き換える")
        XCTAssertNil(state.evaluate(now: now, id: "r1"))
        XCTAssertEqual(state.mainText, "15")
        press("+2", on: &state)
        XCTAssertEqual(state.mainText, "15 + 2", "「=」の後の演算子は、結果から続ける")
        XCTAssertNil(state.evaluate(now: now, id: "r2"))
        XCTAssertEqual(state.mainText, "17")
        press("4", on: &state)
        XCTAssertEqual(state.mainText, "4", "「=」の後の数字は新しい計算")
        XCTAssertNil(state.lastResult)
        press("C*2", on: &state)
        XCTAssertEqual(state.mainText, "0 × 2", "何もない時の演算子は 0 から")
    }

    func testDigitInputRules() {
        var state: CalculatorState = .initial
        press("007", on: &state)
        XCTAssertEqual(state.mainText, "7", "先頭の 0 は置き換える")
        press("C0.50", on: &state)
        XCTAssertEqual(state.mainText, "0.50", "打った形のまま表示する")
        press("C1.2.3", on: &state)
        XCTAssertEqual(state.mainText, "1.23", "小数点は1つだけ")
        press("C1234567", on: &state)
        XCTAssertEqual(state.mainText, "1,234,567")
        press("C" + String(repeating: "9", count: 20), on: &state)
        XCTAssertEqual(DecimalText.digitCount(state.tokens.first?.text ?? ""), 15, "1つの数は 15 桁まで")
        press("C.", on: &state)
        XCTAssertEqual(state.mainText, "0.")
    }

    func testSignPercentAndBackspace() {
        XCTAssertEqual(result(of: "5~"), "-5")
        XCTAssertEqual(result(of: "50*10%"), "5", "% は今の数を 100 で割る")
        XCTAssertEqual(result(of: "(-5)*2"), "-10", "「(」の直後の − は負の数")
        XCTAssertEqual(result(of: "3*2~"), "-6")

        var state: CalculatorState = .initial
        press("123<", on: &state)
        XCTAssertEqual(state.mainText, "12")
        press("+<", on: &state)
        XCTAssertEqual(state.mainText, "12")
        press("~<", on: &state)
        XCTAssertEqual(state.mainText, "-1")
        press("<", on: &state)
        XCTAssertEqual(state.mainText, "0", "符号だけになった数は消す")
        XCTAssertTrue(state.tokens.isEmpty)
    }

    func testPreviewShowsRunningResult() {
        var state: CalculatorState = .initial
        press("2", on: &state)
        XCTAssertNil(state.previewText, "演算子がなければ途中結果は出さない")
        press("+3*", on: &state)
        XCTAssertEqual(state.previewText, "5")
        press("4", on: &state)
        XCTAssertEqual(state.previewText, "14")
    }

    func testDisplayFormatting() {
        XCTAssertEqual(DecimalText.display(Decimal(string: "1234567890123456789") ?? 0), "1.23456789012346e18")
        XCTAssertEqual(DecimalText.display(Decimal(string: "0.000000000012") ?? 0), "1.2e-11")
        XCTAssertEqual(DecimalText.display(Decimal(string: "-1234.5") ?? 0), "-1,234.5")
        XCTAssertEqual(DecimalText.display(Decimal(string: "999999999999999.9") ?? 0), "1e15", "丸めて桁が増えたら指数で表す")
        XCTAssertEqual(DecimalText.display(Decimal(string: "0.000001") ?? 0), "0.000001")
        XCTAssertEqual(DecimalText.display(0), "0")
        XCTAssertEqual(DecimalText.grouped("-1234567.50"), "-1,234,567.50")
        XCTAssertFalse(DecimalText.isLiteral("12abc"), "Decimal(string:) は先頭だけ読むので、先に形を確かめる")
        XCTAssertFalse(DecimalText.isLiteral("1.2.3"))
        XCTAssertFalse(DecimalText.isLiteral("-"))
        XCTAssertTrue(DecimalText.isLiteral("3."))
    }

    func testHistoryIsKeptNewestFirstAndLimited() {
        var state: CalculatorState = .initial
        for index in 0..<(CalculatorState.maximumHistory + 5) {
            press("C\(index)+1", on: &state)
            XCTAssertNil(state.evaluate(now: now, id: "r\(index)"))
        }
        XCTAssertEqual(state.history.count, CalculatorState.maximumHistory)
        XCTAssertEqual(state.history.first?.expression, "54 + 1")
        XCTAssertEqual(state.history.first?.result, "55")
        guard let oldest = state.history.last else { return XCTFail("履歴がない") }
        state.reuse(oldest)
        XCTAssertEqual(state.mainText, "6", "履歴の結果を次の計算に使える")
        state.clearHistory()
        XCTAssertTrue(state.history.isEmpty)
    }

    func testStateRoundTripsThroughArchive() throws {
        var state: CalculatorState = .initial
        press("12+(3.5*-", on: &state)
        press("4)", on: &state)
        XCTAssertNil(state.evaluate(now: now, id: "r1"))
        press("*(2-0.5", on: &state)
        let data: Data = try MiniAppArchiveCodec.encode(state)
        XCTAssertEqual(try MiniAppArchiveCodec.decode(CalculatorState.self, from: data), state)

        let broken = Data(#"{"schemaVersion": 1, "app": "calculator", "content": {"tokens": ["12abc"], "history": []}}"#.utf8)
        XCTAssertThrowsError(try MiniAppArchiveCodec.decode(CalculatorState.self, from: broken), "数でない要素は読まない")
    }
}
