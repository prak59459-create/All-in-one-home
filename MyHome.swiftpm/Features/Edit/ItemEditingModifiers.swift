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

/// 編集中の項目の操作。ドラッグして別の項目に重ねると、その位置へ移す（F0059、F0100。ページ・Dock・フォルダをまたげる）。
/// フォルダに重ねると中に入れる（F0146）。タップすると名前・記号・色・移動先を変えるシートを開く（フォルダは開く）。
/// ドラッグを使わない方法として、VoiceOver の操作に「編集」「前に移動」「後ろに移動」「削除」を用意する。
@MainActor
struct EditingItemModifier: ViewModifier {
    let item: HomeItem
    let iconSize: CGFloat
    @Environment(HomeStore.self) private var store
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                open()
            }
            .draggable(item.id) {
                ItemTile(item: item, size: iconSize)
            }
            .dropDestination(for: String.self) { droppedIDs, _ in
                moveDropped(droppedIDs)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.title)
            .accessibilityHint(item.isFolder ? "編集中です。ダブルタップでフォルダを開きます" : "編集中です。ダブルタップで名前や移動先を変えます")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                open()
            }
            .accessibilityActions {
                Button("編集") { router.presentItemEditor(for: item) }
                Button("前に移動") { move(by: -1) }
                Button("後ろに移動") { move(by: 1) }
                if item.isRemovable {
                    Button("削除") { router.requestRemoval(of: item) }
                }
            }
    }

    private func open() {
        if item.isFolder {
            router.openFolder(item)
        } else {
            router.presentItemEditor(for: item)
        }
    }

    private func moveDropped(_ droppedIDs: [String]) -> Bool {
        guard let movingID = droppedIDs.first, movingID != item.id else { return false }
        return DropMover.perform(store: store, router: router) { store in
            try store.move(itemID: movingID, onto: item.id)
        }
    }

    private func move(by offset: Int) {
        try? store.move(itemID: item.id, by: offset)
    }
}
