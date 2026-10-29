import SwiftUI

/// 画面下の Dock（F0081）。半透明の素材で壁紙とのコントラストを保つ（F0653）。
/// 狭いウィンドウでは小さいアイコンに切り替え、それでも入らなければ横スクロールにする（F0117、F0118）。
@MainActor
struct DockView: View {
    let items: [HomeItem]

    var body: some View {
        if !items.isEmpty {
            // 間隔と余白は、IconTile が四方に持つ Icon.badgeInset（7pt）を差し引いた値
            ViewThatFits(in: .horizontal) {
                DockRow(items: items, iconSize: DesignTokens.Icon.dockSize, spacing: DesignTokens.Spacing.small)
                DockRow(items: items, iconSize: DesignTokens.Icon.compactDockSize, spacing: 0)
                ScrollView(.horizontal) {
                    DockRow(items: items, iconSize: DesignTokens.Icon.compactDockSize, spacing: 0)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.medium)
        }
    }
}

@MainActor
struct DockRow: View {
    let items: [HomeItem]
    let iconSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(items) { item in
                DockItemButton(item: item, iconSize: iconSize)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
    }
}

/// Dock の1項目。名前は表示せず、読み上げで伝える。
@MainActor
struct DockItemButton: View {
    let item: HomeItem
    let iconSize: CGFloat
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.launch(item)
        } label: {
            IconTile(symbolName: item.symbolName, tint: item.tint, badge: item.badge, size: iconSize)
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(item.title)
        .accessibilityHint(item.accessibilityHint)
    }
}
