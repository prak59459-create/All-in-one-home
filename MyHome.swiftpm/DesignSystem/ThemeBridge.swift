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

private struct ImageWallpaperKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// 壁紙が画像か。画像の上では文字を白にして影を付け、読みやすくする（F0979 の考え方を写真にも当てはめる）。
    var isImageWallpaper: Bool {
        get { self[ImageWallpaperKey.self] }
        set { self[ImageWallpaperKey.self] = newValue }
    }
}

extension ThemePalette {
    /// 画像の壁紙の上で使う配色（文字は白。画像の明るさは選べないので、影と暗さの調整で読みやすさを保つ）。
    var forImageWallpaper: ThemePalette {
        ThemePalette(wallpaperTop: wallpaperTop, wallpaperBottom: wallpaperBottom, label: .white, accent: accent)
    }
}

/// 画像の壁紙の上の文字に影を付ける。
@MainActor
struct LegibleOnWallpaper: ViewModifier {
    @Environment(\.isImageWallpaper) private var isImageWallpaper

    @ViewBuilder
    func body(content: Content) -> some View {
        if isImageWallpaper {
            content.shadow(color: Color.black.opacity(0.6), radius: 3, x: 0, y: 1)
        } else {
            content
        }
    }
}
