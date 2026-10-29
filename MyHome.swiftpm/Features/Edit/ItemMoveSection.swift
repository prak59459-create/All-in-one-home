import SwiftUI

/// 項目の移動先（ドラッグを使わない移動）。ページ・Dock・フォルダから選ぶ。選ぶとすぐ移してシートを閉じる。
@MainActor
struct ItemMoveSection: View {
    let item: HomeItem
    let onDone: @MainActor () -> Void
    @Environment(HomeStore.self) private var store
    @State private var failure: String?

    var body: some View {
        Section {
            ForEach(pageChoices, id: \.self) { index in
                Button("ページ \(index + 1) に移動") {
                    move(to: .page(index))
                }
            }
            if location?.container != .dock {
                Button("Dock に移動") {
                    move(to: .dock)
                }
                .disabled(store.layout.dock.count >= HomeLayout.maximumDockItems)
            }
            if !item.isFolder {
                folderChoices
            }
            if let failure {
                Text(failure)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("移動")
        } footer: {
            Text("ドラッグでも移せます。ページの点に重ねるとそのページに、Dock に重ねると Dock に、フォルダに重ねると中に入ります。")
        }
    }

    @ViewBuilder
    private var folderChoices: some View {
        ForEach(otherFolders) { folder in
            Button("フォルダ「\(folder.title)」に入れる") {
                move(to: .folder(folder.id))
            }
        }
        if isTopLevel {
            Button("新しいフォルダを作って入れる") {
                perform { try store.makeFolder(containing: item.id, folderID: "folder.\(UUID().uuidString.lowercased())") }
            }
        }
    }

    private var location: ItemLocation? {
        store.layout.location(ofItem: item.id)
    }

    private var isTopLevel: Bool {
        store.layout.topLevelLocation(ofItem: item.id) != nil
    }

    /// 今いるページ以外のページ（フォルダや Dock の中なら全ページ）。
    private var pageChoices: [Int] {
        let current: ItemContainer? = location?.container
        return store.layout.pages.indices.filter { (index: Int) -> Bool in current != .page(index) }
    }

    private var otherFolders: [HomeItem] {
        let current: ItemContainer? = location?.container
        return store.layout.allFolders().filter { (folder: HomeItem) -> Bool in current != .folder(folder.id) }
    }

    private func move(to destination: ItemDestination) {
        perform { try store.move(itemID: item.id, to: destination) }
    }

    private func perform(_ change: () throws -> Void) {
        do {
            try change()
            onDone()
        } catch let error as LayoutEditError {
            failure = error.message
        } catch {
            failure = "移動できませんでした。"
        }
    }
}
