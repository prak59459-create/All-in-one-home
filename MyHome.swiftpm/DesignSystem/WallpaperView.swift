import SwiftUI

/// テーマの配色によるグラデーションの壁紙（F0646）。画像の壁紙は Phase 4。
@MainActor
struct WallpaperView: View {
    let palette: ThemePalette

    var body: some View {
        let colors: [Color] = [palette.wallpaperTop.color, palette.wallpaperBottom.color]
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
