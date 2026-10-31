/// UI フレームワークに依存しない sRGB 色（各成分 0...1）。SwiftUI の Color への変換は DesignSystem で行う。
struct RGBAColor: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = RGBAColor.clamped(red)
        self.green = RGBAColor.clamped(green)
        self.blue = RGBAColor.clamped(blue)
        self.alpha = RGBAColor.clamped(alpha)
    }

    /// 0xRRGGBB 形式の16進数から作る。
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: RGBAColor.component(of: hex, shift: 16),
            green: RGBAColor.component(of: hex, shift: 8),
            blue: RGBAColor.component(of: hex, shift: 0),
            alpha: alpha
        )
    }

    static let white = RGBAColor(red: 1, green: 1, blue: 1)
    static let black = RGBAColor(red: 0, green: 0, blue: 0)

    private static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    /// 1成分（8ビット）を取り出す。シフトとリテラルを1つの式に混ぜると型推論が遅くなるため、型を明示して分ける。
    private static func component(of hex: UInt32, shift: UInt32) -> Double {
        let byte: UInt32 = (hex >> shift) & 0xFF
        return Double(byte) / 255
    }
}
