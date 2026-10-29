import SwiftUI

/// 編集中でない時の長押しメニュー（F0077）。編集モードへの切り替えと削除。
/// VoiceOver ではこのメニューの項目が「操作」として読み上げられる。
@MainActor
struct ItemContextMenuModifier: ViewModifier {
    let item: HomeItem
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                router.beginEditing()
            } label: {
                Label("ホーム画面を編集", systemImage: "square.and.pencil")
            }
            if item.isRemovable {
                Button(role: .destructive) {
                    router.requestRemoval(of: item)
                } label: {
                    Label("削除", systemImage: "minus.circle")
                }
            }
        }
    }
}

/// 編集中の項目の操作。ドラッグして別の項目に重ねると並べ替える（F0059。同じページ・Dock の中だけ）。
/// ドラッグを使わない方法として、VoiceOver の操作に「前に移動」「後ろに移動」「削除」を用意する。
@MainActor
struct EditingItemModifier: ViewModifier {
    let item: HomeItem
    let iconSize: CGFloat
    @Environment(HomeStore.self) private var store
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content
            .draggable(item.id) {
                IconTile(symbolName: item.symbolName, tint: item.tint, badge: nil, size: iconSize)
            }
            .dropDestination(for: String.self) { droppedIDs, _ in
                moveDropped(droppedIDs)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.title)
            .accessibilityHint("編集中です。操作の一覧から移動や削除ができます")
            .accessibilityActions {
                Button("前に移動") { move(by: -1) }
                Button("後ろに移動") { move(by: 1) }
                if item.isRemovable {
                    Button("削除") { router.requestRemoval(of: item) }
                }
            }
    }

    private func moveDropped(_ droppedIDs: [String]) -> Bool {
        guard let movingID = droppedIDs.first, movingID != item.id else { return false }
        do {
            try store.move(itemID: movingID, onto: item.id)
            return true
        } catch LayoutEditError.differentContainer {
            router.showNotice(title: "移動できません", message: LayoutEditError.differentContainer.message)
            return false
        } catch {
            // ホーム画面の項目ではない文字列（他のアプリからのドラッグなど）は無視する
            return false
        }
    }

    private func move(by offset: Int) {
        try? store.move(itemID: item.id, by: offset)
    }
}
