/// 色を "#RRGGBB"（不透明）または "#RRGGBBAA" の文字列と相互に変換する。各成分は 8 ビットに丸める。
/// 保存形式（SavedHome）で使う。
extension RGBAColor {
    init?(hexString: String) {
        guard hexString.hasPrefix("#") else { return nil }
        let digits: Substring = hexString.dropFirst()
        guard digits.count == 6 || digits.count == 8 else { return nil }
        // UInt32(_:radix:) は先頭の "+" も受け付けるため、16進数の文字だけであることを先に確かめる
        guard digits.utf8.allSatisfy(RGBAColor.isHexDigit) else { return nil }
        guard let value = UInt32(digits, radix: 16) else { return nil }
        if digits.count == 6 {
            self.init(hex: value)
        } else {
            let alphaByte: UInt32 = value & 0xFF
            self.init(hex: value >> 8, alpha: Double(alphaByte) / 255)
        }
    }

    var hexString: String {
        let rgb: String = RGBAColor.hexByte(red) + RGBAColor.hexByte(green) + RGBAColor.hexByte(blue)
        if RGBAColor.byte(alpha) == 255 {
            return "#" + rgb
        }
        return "#" + rgb + RGBAColor.hexByte(alpha)
    }

    private static func isHexDigit(_ code: UInt8) -> Bool {
        let isNumber: Bool = code >= 0x30 && code <= 0x39
        let isUpper: Bool = code >= 0x41 && code <= 0x46
        let isLower: Bool = code >= 0x61 && code <= 0x66
        return isNumber || isUpper || isLower
    }

    private static func byte(_ component: Double) -> UInt32 {
        let scaled: Double = (component * 255).rounded()
        return UInt32(min(max(scaled, 0), 255))
    }

    private static func hexByte(_ component: Double) -> String {
        let text: String = String(byte(component), radix: 16, uppercase: true)
        return text.count == 1 ? "0" + text : text
    }
}
