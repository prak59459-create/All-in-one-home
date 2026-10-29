import SwiftUI

/// ホーム画面のルート。壁紙・時計・ページ・ページインジケーター・Dock を縦に並べる。
/// 各部品は別ファイルの小さな View にし、ここでは並べることだけを行う。
@MainActor
struct HomeScreen: View {
    @Environment(HomeStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.colorScheme) private var colorScheme
    @State private var pageIndex: Int = 0

    var body: some View {
        ZStack {
            WallpaperView(palette: palette)
            content
        }
        .environment(\.homePalette, palette)
        .preferredColorScheme(settings.appearance.colorScheme)
        .modifier(LaunchPresentationModifier(router: router))
    }

    private var palette: ThemePalette {
        settings.theme.palette(isDark: colorScheme == .dark)
    }

    private var content: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            ClockHeaderView()
            PagedGridView(pages: store.layout.pages, selection: $pageIndex)
            PageIndicatorView(count: store.layout.pages.count, selection: $pageIndex)
            DockView(items: store.layout.dock)
        }
        .padding(.vertical, DesignTokens.Spacing.medium)
    }
}

@MainActor
struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
            .environment(HomeStore())
            .environment(SettingsStore())
            .environment(AppRouter())
    }
}
