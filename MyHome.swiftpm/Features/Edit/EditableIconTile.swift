import SwiftUI

/// 項目のアイコン。編集中は削除できる項目の左上に − ボタンを重ねる（F0042）。
/// − ボタンは IconTile の余白（Icon.badgeInset）の内側に置くので、スクロール領域の端でも切れない。
@MainActor
struct EditableIconTile: View {
    let item: HomeItem
    let size: CGFloat
    @Environment(AppRouter.self) private var router

    var body: some View {
        ItemTile(item: item, size: size)
            .overlay(alignment: .topLeading) {
                if router.isEditing && item.isRemovable {
                    RemoveItemButton(item: item)
                }
            }
    }
}

@MainActor
struct RemoveItemButton: View {
    let item: HomeItem
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.requestRemoval(of: item)
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white, Color.black.opacity(0.75))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("「\(item.title)」を削除")
    }
}
