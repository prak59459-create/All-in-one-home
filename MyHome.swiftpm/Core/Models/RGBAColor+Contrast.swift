import Foundation

extension RGBAColor {
    /// WCAG 2.x の相対輝度（不透明として計算する）。
    var relativeLuminance: Double {
        let red: Double = RGBAColor.linearized(self.red)
        let green: Double = RGBAColor.linearized(self.green)
        let blue: Double = RGBAColor.linearized(self.blue)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// 2色のコントラスト比（1...21）。文字は 4.5 以上、アイコンなどの部品は 3 以上を目安にする。
    func contrastRatio(with other: RGBAColor) -> Double {
        let mine: Double = relativeLuminance
        let theirs: Double = other.relativeLuminance
        let lighter: Double = max(mine, theirs)
        let darker: Double = min(mine, theirs)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// この色を背景にした時に読みやすい前景色（白または黒の、コントラストが高い方）。
    var readableForeground: RGBAColor {
        let onWhite: Double = contrastRatio(with: .white)
        let onBlack: Double = contrastRatio(with: .black)
        return onWhite >= onBlack ? .white : .black
    }

    private static func linearized(_ component: Double) -> Double {
        if component <= 0.04045 {
            return component / 12.92
        }
        return pow((component + 0.055) / 1.055, 2.4)
    }
}
