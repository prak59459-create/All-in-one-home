import Foundation

/// 電卓の数の文字列（F0504）。計算は Decimal（10 進数）で行い、0.1 + 0.2 が 0.3 になるようにする。
/// 区切りの記号は端末の設定によらず「,」と「.」に固定する（テストと保存の形を一定にするため）。
enum DecimalText {
    /// 画面に出す有効桁数。
    static let significantDigits: Int = 15
    /// Swift 5.10 の Foundation では Locale が Sendable でないため、static let にしない。
    private static var posix: Locale {
        Locale(identifier: "en_US_POSIX")
    }

    /// 数の書き方として正しいか（"-12"、"0.5"、"3." など）。Decimal(string:) は "12abc" も 12 と読むので、先に確かめる。
    static func isLiteral(_ text: String) -> Bool {
        var rest: Substring = Substring(text)
        if rest.hasPrefix("-") {
            rest = rest.dropFirst()
        }
        let parts: [Substring] = rest.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard let whole = parts.first, !whole.isEmpty, whole.allSatisfy(DecimalText.isDigit) else { return false }
        if parts.count == 2 {
            return parts[1].allSatisfy(DecimalText.isDigit)
        }
        return true
    }

    static func parse(_ text: String) -> Decimal? {
        guard isLiteral(text) else { return nil }
        return Decimal(string: text, locale: posix)
    }

    /// 保存用の形（区切りなし、丸めない）。
    static func canonical(_ value: Decimal) -> String {
        value.isZero ? "0" : value.description
    }

    /// 数字の数（符号と小数点を除く）。
    static func digitCount(_ text: String) -> Int {
        text.filter(DecimalText.isDigit).count
    }

    /// 画面に出す形。15 桁に丸め、3 桁ごとに区切る。とても大きい数・小さい数は指数で表す（例: 1.5e-12）。
    static func display(_ value: Decimal) -> String {
        guard !value.isNaN else { return "エラー" }
        guard !value.isZero else { return "0" }
        let isNegative: Bool = value < 0
        let magnitude: Decimal = isNegative ? -value : value
        let body: String = displayMagnitude(magnitude)
        return isNegative ? "-" + body : body
    }

    /// 入力中の数の表示。打った形（末尾の「.」や 0）を残して区切る。桁が多すぎる時（計算結果を続けて使う時）は丸める。
    static func displayLiteral(_ text: String) -> String {
        if digitCount(text) > significantDigits, let value = parse(text) {
            return display(value)
        }
        return grouped(text)
    }

    /// 有効桁 15 桁に丸める。
    static func rounded(_ value: Decimal) -> Decimal {
        guard !value.isNaN, !value.isZero else { return value }
        let magnitude: Decimal = value < 0 ? -value : value
        return round(value, scale: significantDigits - integerDigits(of: magnitude))
    }

    private static func displayMagnitude(_ magnitude: Decimal) -> String {
        let digits: Int = integerDigits(of: magnitude)
        if digits > significantDigits || digits < -9 {
            return scientific(magnitude, exponent: digits - 1)
        }
        let value: Decimal = round(magnitude, scale: significantDigits - digits)
        if integerDigits(of: value) > significantDigits {
            return scientific(value, exponent: integerDigits(of: value) - 1)
        }
        return grouped(canonical(value))
    }

    /// 1 以上なら整数部の桁数。1 未満なら、小数点の後に続く 0 の数を負にしたもの（0.0012 → -2）。
    private static func integerDigits(of magnitude: Decimal) -> Int {
        let text: String = magnitude.description
        let parts: [Substring] = text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let whole: Substring = parts.first ?? "0"
        if whole != "0" {
            return whole.count
        }
        let fraction: Substring = parts.count == 2 ? parts[1] : ""
        let zeros: Substring = fraction.prefix(while: { (character: Character) -> Bool in character == "0" })
        return -zeros.count
    }

    private static func scientific(_ magnitude: Decimal, exponent: Int) -> String {
        var power: Int = exponent
        var mantissa: Decimal = round(magnitude / powerOfTen(power), scale: significantDigits - 1)
        if mantissa >= 10 {
            mantissa = mantissa / 10
            power += 1
        }
        return "\(canonical(mantissa))e\(power)"
    }

    private static func powerOfTen(_ exponent: Int) -> Decimal {
        Decimal(sign: .plus, exponent: exponent, significand: Decimal(1))
    }

    private static func round(_ value: Decimal, scale: Int) -> Decimal {
        var input: Decimal = value
        var result: Decimal = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
    }

    /// 整数部を 3 桁ごとに「,」で区切る（"-1234567.50" → "-1,234,567.50"）。
    static func grouped(_ text: String) -> String {
        var rest: Substring = Substring(text)
        var sign: String = ""
        if rest.hasPrefix("-") {
            sign = "-"
            rest = rest.dropFirst()
        }
        let parts: [Substring] = rest.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let whole: [Character] = Array(parts.first ?? "")
        var groupedWhole: String = ""
        for (offset, character) in whole.enumerated() {
            if offset > 0 && (whole.count - offset) % 3 == 0 {
                groupedWhole.append(",")
            }
            groupedWhole.append(character)
        }
        let fraction: String = parts.count == 2 ? "." + parts[1] : ""
        return sign + groupedWhole + fraction
    }

    private static func isDigit(_ character: Character) -> Bool {
        character >= "0" && character <= "9"
    }
}
