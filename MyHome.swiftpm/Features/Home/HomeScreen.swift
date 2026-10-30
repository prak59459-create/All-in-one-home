import SwiftUI

/// ホーム画面のルート。壁紙・時計・ページ・ページインジケーター・Dock を縦に並べる。
/// 各部品は別ファイルの小さな View にし、ここでは並べることだけを行う。
@MainActor
struct HomeScreen: View {
    @Environment(HomeStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.imageStore) private var imageStore
    @Environment(\.motionLevel) private var motion
    @State private var pageIndex: Int = 0

    var body: some View {
        ZStack {
            WallpaperView(palette: palette, wallpaper: settings.wallpaper)
            content
            if let folderID = router.openFolderID {
                FolderOverlayView(folderID: folderID)
                    .transition(MotionStyle.appear(motion))
            }
        }
        // フォルダの開閉と編集モードの切り替えは、動きの設定に従ってアニメーションする（F0660、F0672）
        .animation(MotionStyle.standard(motion), value: router.openFolderID)
        .animation(MotionStyle.standard(motion), value: router.isEditing)
        .background {
            HomeKeyboardShortcuts(pageIndex: $pageIndex, pageCount: store.layout.pages.count)
        }
        .environment(\.homePalette, isImageWallpaper ? palette.forImageWallpaper : palette)
        .environment(\.isImageWallpaper, isImageWallpaper)
        .preferredColorScheme(settings.appearance.colorScheme)
        .modifier(LaunchPresentationModifier(router: router))
        .onChange(of: store.layout.pages.count) { _, count in
            // ページが減って、表示中のページがなくなった時
            if pageIndex >= count {
                pageIndex = max(count - 1, 0)
            }
        }
    }

    private var palette: ThemePalette {
        settings.theme.palette(isDark: colorScheme == .dark)
    }

    /// 画像の壁紙を表示しているか（ファイルがなければグラデーションなので false）。
    private var isImageWallpaper: Bool {
        guard let name = settings.wallpaper.imageFileName else { return false }
        return imageStore?.exists(name) ?? false
    }

    private var content: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            header
            SaveStatusBanner()
            PagedGridView(pages: store.layout.pages, selection: $pageIndex)
            PageIndicatorView(count: store.layout.pages.count, selection: $pageIndex)
            DockView(items: store.layout.dock)
        }
        .padding(.vertical, DesignTokens.Spacing.medium)
    }

    /// 編集中は時計を薄くし、その上に編集のバーを重ねる（グリッドの位置が動かないようにする）。
    private var header: some View {
        ClockHeaderView(showsSeconds: settings.showsSeconds)
            .opacity(router.isEditing ? 0.3 : 1)
            .overlay(alignment: .top) {
                if router.isEditing {
                    EditModeBar(pageIndex: pageIndex)
                        .transition(MotionStyle.appear(motion))
                }
            }
    }
}

@MainActor
struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        let boot: AppBootstrap = AppBootstrap.make(storage: PreviewArchiveStorage())
        return HomeScreen()
            .environment(boot.home)
            .environment(boot.settings)
            .environment(boot.persistence)
            .environment(boot.timers)
            .environment(boot.miniApps)
            .environment(AppRouter())
    }
}
