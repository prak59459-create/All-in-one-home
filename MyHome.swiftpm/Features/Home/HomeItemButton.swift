import SwiftUI

/// ホーム画面の1項目。タップ後に何をするかは AppRouter（LaunchPlanner）が決める。
/// 編集中はボタンにせず、並べ替えと削除の操作だけを受け付ける。
@MainActor
struct HomeItemButton: View {
    let item: HomeItem
    @Environment(AppRouter.self) private var router
    @Environment(\.homePalette) private var palette

    var body: some View {
        if router.isEditing {
            content
                .modifier(EditingItemModifier(item: item, iconSize: DesignTokens.Icon.size))
        } else {
            Button {
                router.launch(item)
            } label: {
                content
            }
            .buttonStyle(IconPressStyle())
            .modifier(ItemContextMenuModifier(item: item))
            .accessibilityLabel(item.title)
            .accessibilityHint(item.accessibilityHint)
        }
    }

    private var content: some View {
        // IconTile の下側にも Icon.badgeInset の余白があるので、名前との間隔は小さくする
        VStack(spacing: DesignTokens.Spacing.xSmall) {
            EditableIconTile(item: item, size: DesignTokens.Icon.size)
            title
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
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
