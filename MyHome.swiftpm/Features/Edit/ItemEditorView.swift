import SwiftUI

/// 編集中に項目をタップすると開くシート。名前・記号・色の変更（F0044、F0046、F0050）、
/// 移動先の選択（ドラッグを使わない移動。F0061、F0127）、フォルダの作成（F0121）、削除・フォルダの解除。
@MainActor
struct ItemEditorView: View {
    let itemID: String
    @Environment(HomeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var symbolName: String = ""
    @State private var tint: RGBAColor = .black
    @State private var isLoaded: Bool = false
    @State private var isConfirmingRemoval: Bool = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("項目の編集")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .onAppear {
            load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let item = store.layout.item(id: itemID) {
            Form {
                ItemLooksSection(item: item, title: $title, symbolName: $symbolName, tint: $tint)
                ItemMoveSection(item: item, onDone: finish)
                removalSection(for: item)
                if let failure {
                    Text(failure)
                        .foregroundStyle(.red)
                }
            }
            .confirmationDialog(AppAlert.confirmRemoval(item).title, isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
                Button(item.isFolder ? "解除" : "削除", role: .destructive) {
                    remove(item)
                }
            } message: {
                Text(AppAlert.confirmRemoval(item).message)
            }
        } else {
            ContentUnavailableView("項目が見つかりません", systemImage: "questionmark.square.dashed")
        }
    }

    @ViewBuilder
    private func removalSection(for item: HomeItem) -> some View {
        if item.isRemovable {
            Section {
                Button(item.isFolder ? "フォルダを解除" : "削除", role: .destructive) {
                    isConfirmingRemoval = true
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("キャンセル") {
                dismiss()
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("保存") {
                save()
            }
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func load() {
        guard !isLoaded, let item = store.layout.item(id: itemID) else { return }
        title = item.title
        symbolName = item.symbolName
        tint = item.tint
        isLoaded = true
    }

    private func save() {
        let trimmed: String = title.trimmingCharacters(in: .whitespacesAndNewlines)
        perform { try store.update(itemID: itemID, title: trimmed, symbolName: symbolName, tint: tint) }
    }

    private func remove(_ item: HomeItem) {
        perform { try store.remove(itemID: item.id) }
    }

    private func perform(_ change: () throws -> Void) {
        do {
            try change()
            finish()
        } catch let error as LayoutEditError {
            failure = error.message
        } catch {
            failure = "変更できませんでした。"
        }
    }

    private func finish() {
        dismiss()
    }
}

/// 名前・記号・色。フォルダは名前だけ（アイコンは中の項目から作る）。
@MainActor
struct ItemLooksSection: View {
    let item: HomeItem
    @Binding var title: String
    @Binding var symbolName: String
    @Binding var tint: RGBAColor

    var body: some View {
        Section("名前") {
            TextField("名前", text: $title)
        }
        if !item.isFolder {
            Section("記号") {
                SymbolChoiceGrid(selection: $symbolName, tint: tint, symbols: symbolChoices)
            }
            Section("色") {
                ColorChoiceRow(selection: $tint)
            }
        }
    }

    /// 今の記号が選択肢になければ先頭に足す（初期配置の記号は選択肢と違うことがある）。
    private var symbolChoices: [String] {
        let base: [String] = IconChoices.symbols
        return base.contains(item.symbolName) ? base : [item.symbolName] + base
    }
}
