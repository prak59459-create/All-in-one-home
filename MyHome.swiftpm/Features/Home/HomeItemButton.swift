import SwiftUI

/// ホーム画面の1項目。タップ後に何をするかは AppRouter（LaunchPlanner）が決める。
@MainActor
struct HomeItemButton: View {
    let item: HomeItem
    @Environment(AppRouter.self) private var router
    @Environment(\.homePalette) private var palette

    var body: some View {
        Button {
            router.launch(item)
        } label: {
            VStack(spacing: DesignTokens.Spacing.small) {
                IconTile(symbolName: item.symbolName, tint: item.tint, badge: item.badge, size: DesignTokens.Icon.size)
                title
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(item.title)
        .accessibilityHint(item.accessibilityHint)
    }

    private var title: some View {
        Text(item.title)
            .font(.caption)
            .foregroundStyle(palette.label.color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: DesignTokens.Icon.labelWidth)
    }
}
