import Foundation
import XCTest
@testable import MyHomeCore

/// T5-5・T5-6: 単位変換とテキストツール。
final class ConverterAndTextToolsTests: XCTestCase {
    private func unit(_ id: String) -> MeasureUnit {
        guard let found = UnitCatalog.unit(id: id) else {
            preconditionFailure("単位がない: \(id)")
        }
        return found
    }

    private func convert(_ value: Double, _ from: String, _ to: String) -> Double {
        UnitConverter.convert(value, from: unit(from), to: unit(to))
    }

    // MARK: - 単位変換

    func testKnownConversions() {
        XCTAssertEqual(convert(1, "length.in", "length.cm"), 2.54, accuracy: 1e-12)
        XCTAssertEqual(convert(1, "length.mi", "length.km"), 1.609344, accuracy: 1e-12)
        XCTAssertEqual(convert(100, "temperature.c", "temperature.f"), 212, accuracy: 1e-9)
        XCTAssertEqual(convert(-40, "temperature.c", "temperature.f"), -40, accuracy: 1e-9)
        XCTAssertEqual(convert(0, "temperature.k", "temperature.c"), -273.15, accuracy: 1e-9)
        XCTAssertEqual(convert(1, "area.tsubo", "area.m2"), 3.305785123966942, accuracy: 1e-9)
        XCTAssertEqual(convert(1, "volume.go", "volume.ml"), 180.390683696, accuracy: 1e-6)
        XCTAssertEqual(convert(1, "data.gib", "data.b"), 1_073_741_824, accuracy: 0)
        XCTAssertEqual(convert(90, "speed.kmh", "speed.mps"), 25, accuracy: 1e-9)
        XCTAssertEqual(convert(1, "time.d", "time.min"), 1440, accuracy: 1e-9)
    }

    func testEveryUnitRoundTripsAndIDsAreUnique() {
        var ids: Set<String> = []
        for category in UnitCatalog.categories {
            let base: MeasureUnit = category.units[0]
            for item in category.units {
                XCTAssertTrue(ids.insert(item.id).inserted, "ID の重複: \(item.id)")
                XCTAssertTrue(item.id.hasPrefix(category.id + "."), item.id)
                let there: Double = UnitConverter.convert(123.456, from: item, to: base)
                XCTAssertEqual(UnitConverter.convert(there, from: base, to: item), 123.456, accuracy: 1e-9, item.id)
            }
        }
    }

    func testParseAcceptsJapaneseInputAndRejectsOthers() {
        XCTAssertEqual(UnitConverter.parse("１，２３４．５"), 1234.5, "全角の数字・記号も読む")
        XCTAssertEqual(UnitConverter.parse(" −3 "), -3)
        XCTAssertEqual(UnitConverter.parse("1e3"), 1000)
        XCTAssertNil(UnitConverter.parse("abc"))
        XCTAssertNil(UnitConverter.parse(""))
        XCTAssertNil(UnitConverter.parse("1..2"))
        XCTAssertNil(UnitConverter.parse("inf"))
    }

    func testFormat() {
        XCTAssertEqual(UnitConverter.format(1_234_567.891), "1,234,567.891")
        XCTAssertEqual(UnitConverter.format(0.1 + 0.2), "0.3", "有効数字 10 桁で丸める")
        XCTAssertEqual(UnitConverter.format(1.0 / 3.0), "0.3333333333")
        XCTAssertEqual(UnitConverter.format(-0.0), "0")
        XCTAssertEqual(UnitConverter.format(1e15), "1e+15")
        XCTAssertEqual(UnitConverter.format(0.0000012), "1.2e-06")
        XCTAssertEqual(UnitConverter.format(-2.54), "-2.54")
    }

    func testConverterStateKeepsSelectionsValid() {
        var state: ConverterState = .initial
        XCTAssertEqual(state.results().count, UnitCatalog.length.units.count)
        state.selectCategory("temperature")
        XCTAssertEqual(state.sourceUnitID, "temperature.c")
        state.selectSourceUnit("length.m")
        XCTAssertEqual(state.sourceUnitID, "temperature.c", "別の種類の単位は選べない")
        state.selectCategory("mass")
        XCTAssertEqual(state.sourceUnitID, "mass.kg", "基準の単位があればそれを選ぶ")
        state.setInput(String(repeating: "1", count: 100))
        XCTAssertEqual(state.input.count, ConverterState.maximumInputLength)
        state.setInput("abc")
        XCTAssertEqual(state.results(), [])

        let unknown = ConverterState(categoryID: "removed", sourceUnitID: "removed.x", input: "1")
        XCTAssertEqual(unknown.category.id, "length", "なくなった種類は長さとして扱う")
        XCTAssertEqual(unknown.sourceUnit.id, UnitCatalog.length.units[0].id)
        XCTAssertTrue(unknown.problems.isEmpty, "なくなった ID だけでは読み込みを失敗にしない")
    }

    // MARK: - テキストツール

    func testStatisticsCountWhatPeopleSee() {
        let stats = TextStatistics("こんにちは 世界\n👍🏽が\n\n")
        XCTAssertEqual(stats.characters, 13, "肌の色付きの絵文字も1文字")
        XCTAssertEqual(stats.charactersExcludingWhitespace, 9)
        XCTAssertEqual(stats.lines, 4)
        XCTAssertEqual(stats.nonEmptyLines, 2)
        XCTAssertEqual(stats.words, 3)
        XCTAssertEqual(stats.utf8Bytes, 36)
        XCTAssertEqual(stats.manuscriptPages, 1)

        let empty = TextStatistics("")
        XCTAssertEqual([empty.characters, empty.lines, empty.words, empty.manuscriptPages], [0, 0, 0, 0])
        XCTAssertEqual(TextStatistics("a\r\nb").lines, 2, "CRLF は1つの改行")
        XCTAssertEqual(TextStatistics(String(repeating: "あ", count: 401)).manuscriptPages, 2)
    }

    func testTransforms() {
        XCTAssertEqual(TextTransform.trimLines.apply("  a  \n\tb"), "a\nb")
        XCTAssertEqual(TextTransform.removeEmptyLines.apply("a\n\n \u{3000}\nb"), "a\nb")
        XCTAssertEqual(TextTransform.removeDuplicateLines.apply("b\na\nb\na"), "b\na", "最初に出た行を残す")
        XCTAssertEqual(TextTransform.sortLines.apply("item10\nitem2\nItem1"), "Item1\nitem2\nitem10", "数は大きさで比べる")
        XCTAssertEqual(TextTransform.joinLines.apply("a\nb\r\nc"), "abc")
        XCTAssertEqual(TextTransform.toHalfWidth.apply("ＡＢＣ１２３！\u{3000}ｘ"), "ABC123! x")
        XCTAssertEqual(TextTransform.toFullWidth.apply("Abc 1!"), "Ａｂｃ\u{3000}１！")
        XCTAssertEqual(TextTransform.toHalfWidth.apply("カタカナ"), "カタカナ", "カタカナは変えない")
        XCTAssertEqual(TextTransform.uppercase.apply("abcＡｂｃ"), "ABCＡＢＣ")

        let scalars: [Unicode.Scalar] = (0x20...0x7E).compactMap { (value: Int) -> Unicode.Scalar? in Unicode.Scalar(value) }
        let printable: String = String(String.UnicodeScalarView(scalars))
        XCTAssertEqual(TextWidth.toHalfWidth(TextWidth.toFullWidth(printable)), printable, "全角にして戻すと元どおり")
    }

    func testCodecs() {
        XCTAssertEqual(try TextCodec.base64Encode.apply("あ").get(), "44GC")
        XCTAssertEqual(try TextCodec.base64Decode.apply("44GC").get(), "あ")
        XCTAssertEqual(try TextCodec.base64Decode.apply(" SGVs\nbG8 ").get(), "Hello", "空白と省略した = を受け付ける")
        XCTAssertEqual(try TextCodec.base64Decode.apply("fn5-").get(), "~~~", "URL 用の Base64 も読む")
        XCTAssertThrowsError(try TextCodec.base64Decode.apply("!!!").get())
        XCTAssertThrowsError(try TextCodec.base64Decode.apply("/w==").get(), "文字でないデータは戻さない")
        XCTAssertEqual(try TextCodec.urlEncode.apply("a b/あ~").get(), "a%20b%2F%E3%81%82~")
        XCTAssertEqual(try TextCodec.urlDecode.apply("a%20b%2F%E3%81%82").get(), "a b/あ")
        XCTAssertThrowsError(try TextCodec.urlDecode.apply("%ZZ").get())
    }

    func testJSONIsReformattedWithoutChangingValues() {
        let input: String = #"{"b":1,"a":[true,false,null,{"x":"y{\"}"}],"e":{},"f":[],"n":-1.5e+3,"名前":"太郎"}"#
        let expected: String = """
        {
          "b": 1,
          "a": [
            true,
            false,
            null,
            {
              "x": "y{\\"}"
            }
          ],
          "e": {},
          "f": [],
          "n": -1.5e+3,
          "名前": "太郎"
        }
        """
        XCTAssertEqual(try JSONFormatter.format(input, style: .pretty).get(), expected, "キーの順と数の書き方は変えない")
        XCTAssertEqual(try JSONFormatter.format(expected, style: .compact).get(), input)
    }

    func testJSONErrorsPointAtTheProblem() {
        func message(_ text: String) -> String {
            switch JSONFormatter.format(text, style: .pretty) {
            case .success(let output): return "成功してしまった: \(output)"
            case .failure(let error): return error.message
            }
        }
        XCTAssertTrue(message("{\n  \"名前\" 1}").hasPrefix("2 行目の 8 文字目"), message("{\n  \"名前\" 1}"))
        XCTAssertTrue(message("[1,]").contains("値として読めない"))
        XCTAssertTrue(message("{'a':1}").contains("キー"))
        XCTAssertTrue(message("01").contains("余分な文字"))
        XCTAssertTrue(message("\"a\nb\"").contains("改行"))
        XCTAssertTrue(message("").contains("値がありません"))
        XCTAssertTrue(message("[True]").contains("小文字"))
        XCTAssertTrue(message("\"\\x\"").contains("「\\」"))
        let deep: String = String(repeating: "[", count: 150) + String(repeating: "]", count: 150)
        XCTAssertTrue(message(deep).contains("深すぎます"))
        let shallow: String = String(repeating: "[", count: 50) + String(repeating: "]", count: 50)
        XCTAssertNoThrow(try JSONFormatter.format(shallow, style: .compact).get())
    }

    func testTextToolsStateLimitsLength() {
        var state: TextToolsState = .initial
        XCTAssertFalse(state.setText("abc"))
        XCTAssertEqual(state.text, "abc")
        XCTAssertFalse(state.setText(String(repeating: "a", count: TextToolsState.maximumLength)))
        XCTAssertTrue(state.setText(String(repeating: "あ", count: TextToolsState.maximumLength + 1)))
        XCTAssertEqual(state.text.count, TextToolsState.maximumLength)
    }
}
