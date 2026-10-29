import SwiftUI

/// 壁紙（F0646、F0647、F0650、F0651）。画像があれば画像（ぼかしと暗さを反映）、なければテーマのグラデーション。
/// 画像のファイルがない・読めない時もグラデーションに戻す（F0827）。
@MainActor
struct WallpaperView: View {
    let palette: ThemePalette
    var wallpaper: WallpaperSetting = .themeGradient
    @Environment(\.imageStore) private var imageStore

    var body: some View {
        ZStack {
            gradient
            if let image = loadedImage, case .image(let setting) = wallpaper {
                WallpaperImageLayer(image: image, setting: setting)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var gradient: some View {
        LinearGradient(
            colors: [palette.wallpaperTop.color, palette.wallpaperBottom.color],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var loadedImage: UIImage? {
        ImageCache.shared.image(named: wallpaper.imageFileName, in: imageStore)
    }
}

@MainActor
struct WallpaperImageLayer: View {
    let image: UIImage
    let setting: WallpaperImage

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .blur(radius: CGFloat(setting.blur) * 30, opaque: true)
                .clipped()
                .overlay {
                    Color.black.opacity(setting.dim * 0.7)
                }
        }
    }
}
