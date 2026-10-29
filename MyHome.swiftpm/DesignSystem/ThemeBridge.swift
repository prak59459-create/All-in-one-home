import SwiftUI

extension RGBAColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension ThemeAppearance {
    /// nil の時は端末のライト / ダーク設定に従う。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private struct HomePaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette = ThemeCatalog.indigo.dark
}

extension EnvironmentValues {
    /// ホーム画面の配色。テーマとライト / ダークから HomeScreen が決めて配下へ渡す。
    var homePalette: ThemePalette {
        get { self[HomePaletteKey.self] }
        set { self[HomePaletteKey.self] = newValue }
    }
}
