import SwiftUI

/// ページの管理（F0010、F0011、F0012、F0015）。ページの一覧と項目数、並べ替え、追加、空のページの削除。
@MainActor
struct PageManagerView: View {
    @Environment(HomeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.layout.pages.indices, id: \.self) { index in
                        PageRow(index: index, pageCount: store.layout.pages.count, itemCount: itemCount(at: index), onAction: perform)
                    }
                } footer: {
                    Text("項目が残っているページは削除できません（項目を失わないため）。先に項目を別のページへ移すか、削除してください。")
                }
                Section {
                    Button {
                        perform { try store.addPage(id: "page.\(UUID().uuidString.lowercased())") }
                    } label: {
                        Label("ページを追加", systemImage: "plus")
                    }
                }
                if let failure {
                    Text(failure)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("ページ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func itemCount(at index: Int) -> Int {
        store.layout.pages[index].items.count
    }

    private func perform(_ change: () throws -> Void) {
        do {
            try change()
            failure = nil
        } catch let error as LayoutEditError {
            failure = error.message
        } catch {
            failure = "変更できませんでした。"
        }
    }
}

@MainActor
struct PageRow: View {
    let index: Int
    let pageCount: Int
    let itemCount: Int
    let onAction: @MainActor (() throws -> Void) -> Void
    @Environment(HomeStore.self) private var store

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ページ \(index + 1)")
                Text("\(itemCount) 個の項目")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            rowButton("前へ", symbol: "arrow.up", disabled: index == 0) {
                try store.movePage(at: index, by: -1)
            }
            rowButton("後ろへ", symbol: "arrow.down", disabled: index == pageCount - 1) {
                try store.movePage(at: index, by: 1)
            }
            rowButton("削除", symbol: "trash", disabled: itemCount > 0 || pageCount == 1) {
                try store.removePage(at: index)
            }
        }
    }

    private func rowButton(_ title: String, symbol: String, disabled: Bool, action: @escaping () throws -> Void) -> some View {
        Button {
            onAction(action)
        } label: {
            Label(title, systemImage: symbol)
                .labelStyle(.iconOnly)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
        .accessibilityLabel("ページ \(index + 1) を\(title)")
    }
}
