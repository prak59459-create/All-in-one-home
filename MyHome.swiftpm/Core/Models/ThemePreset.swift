/// 外観の指定。system は端末のライト / ダーク設定に従う。
enum ThemeAppearance: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: return "端末に合わせる"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }
}

/// ライトまたはダークの一方の配色。
struct ThemePalette: Hashable, Sendable {
    let wallpaperTop: RGBAColor
    let wallpaperBottom: RGBAColor
    /// 壁紙の上に置く文字（時計・アイコン名）の色。壁紙の両端に対してコントラスト比 4.5 以上にする。
    let label: RGBAColor
    /// ページインジケーターなどの強調色。壁紙に対してコントラスト比 3 以上にする。
    let accent: RGBAColor
}

/// テーマのプリセット。ライト用とダーク用の配色を持つ。
struct ThemePreset: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let light: ThemePalette
    let dark: ThemePalette

    func palette(isDark: Bool) -> ThemePalette {
        isDark ? dark : light
    }
}
