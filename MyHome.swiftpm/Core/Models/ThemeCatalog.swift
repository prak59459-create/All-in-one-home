/// 組み込みテーマ。保存された ID が見つからない場合は既定テーマを使う。
enum ThemeCatalog {
    static let defaultID: String = "indigo"

    static let all: [ThemePreset] = [indigo, forest, sunset, mono]

    static func preset(id: String) -> ThemePreset {
        all.first { $0.id == id } ?? indigo
    }

    static let indigo = ThemePreset(
        id: "indigo",
        name: "インディゴ",
        light: palette(top: 0xC7D2FE, bottom: 0xEEF2FF, label: 0x1E1B4B, accent: 0x4338CA),
        dark: palette(top: 0x312E81, bottom: 0x0F172A, label: 0xFFFFFF, accent: 0xA5B4FC)
    )

    static let forest = ThemePreset(
        id: "forest",
        name: "フォレスト",
        light: palette(top: 0xBBF7D0, bottom: 0xF0FDF4, label: 0x14532D, accent: 0x15803D),
        dark: palette(top: 0x14532D, bottom: 0x052E16, label: 0xF0FDF4, accent: 0x86EFAC)
    )

    static let sunset = ThemePreset(
        id: "sunset",
        name: "サンセット",
        light: palette(top: 0xFED7AA, bottom: 0xFCE7F3, label: 0x431407, accent: 0xC2410C),
        dark: palette(top: 0x7C2D12, bottom: 0x3B0764, label: 0xFFF7ED, accent: 0xFDBA74)
    )

    static let mono = ThemePreset(
        id: "mono",
        name: "モノクロ",
        light: palette(top: 0xE5E5EA, bottom: 0xF2F2F7, label: 0x1C1C1E, accent: 0x3A3A3C),
        dark: palette(top: 0x2C2C2E, bottom: 0x000000, label: 0xFFFFFF, accent: 0xAEAEB2)
    )

    private static func palette(top: UInt32, bottom: UInt32, label: UInt32, accent: UInt32) -> ThemePalette {
        ThemePalette(
            wallpaperTop: RGBAColor(hex: top),
            wallpaperBottom: RGBAColor(hex: bottom),
            label: RGBAColor(hex: label),
            accent: RGBAColor(hex: accent)
        )
    }
}
