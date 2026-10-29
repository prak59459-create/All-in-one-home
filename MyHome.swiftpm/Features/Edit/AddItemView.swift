import SwiftUI

/// 項目の追加（F0041）。Web リンク・URL スキーム（F0068、F0069）、アプリ内の機能、ウィジェット（F0162）から選ぶ。
/// 追加先は、編集を始めたページの末尾。
@MainActor
struct AddItemView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case link = "リンク"
        case feature = "アプリ内の機能"
        case widget = "ウィジェット"

        var id: String { rawValue }
    }

    let pageIndex: Int
    @Environment(HomeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind = .link
    @State private var draft: LinkDraft = LinkDraft()
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("種類", selection: $kind) {
                    ForEach(Kind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                content
                if let failure {
                    Text(failure)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("項目を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .link:
            AddLinkForm(draft: $draft)
        case .feature:
            AddFeatureList(onAdd: add)
        case .widget:
            AddWidgetList(pageIndex: pageIndex) {
                dismiss()
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
        if kind == .link {
            ToolbarItem(placement: .confirmationAction) {
                Button("追加") {
                    addLink()
                }
                .disabled(draft.makeItem(id: "preview") == nil)
            }
        }
    }

    private func addLink() {
        guard let item = draft.makeItem(id: LinkDraft.newItemID()) else { return }
        add(item)
    }

    private func add(_ item: HomeItem) {
        do {
            try store.add(item, toPage: pageIndex)
            dismiss()
        } catch let error as LayoutEditError {
            failure = error.message
        } catch {
            failure = "追加できませんでした。"
        }
    }
}
