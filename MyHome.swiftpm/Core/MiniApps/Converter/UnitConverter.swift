import Foundation

/// 単位の換算と、数の読み書き（F0505）。
enum UnitConverter {
    static func convert(_ value: Double, from source: MeasureUnit, to target: MeasureUnit) -> Double {
        target.conversion.fromBase(source.conversion.toBase(value))
    }

    /// 入力された数を読む。全角の数字、3 桁ごとの「,」、全角の「−」も受け付ける。読めなければ nil。
    static func parse(_ text: String) -> Double? {
        var cleaned: String = TextWidth.toHalfWidth(text).trimmingCharacters(in: .whitespaces)
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        cleaned = cleaned.replacingOccurrences(of: "−", with: "-")
        guard !cleaned.isEmpty, cleaned.count <= 40 else { return nil }
        let allowed: Set<Character> = Set("0123456789.-+eE")
        guard cleaned.allSatisfy({ (character: Character) -> Bool in allowed.contains(character) }) else { return nil }
        guard let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    /// 表示する形。有効数字 10 桁で、整数部を 3 桁ごとに区切る。とても大きい数・小さい数は指数で表す（例: 1.5e-07）。
    static func format(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        if value == 0 {
            return "0"
        }
        let text: String = String(format: "%.10g", value)
        if text.contains("e") {
            return text
        }
        return DecimalText.grouped(text)
    }
}
