import SwiftUI

/// Web リンク・URL スキームの入力。URL は入力のたびに URLPolicy で確かめ、理由を表示する。
@MainActor
struct AddLinkForm: View {
    @Binding var draft: LinkDraft

    var body: some View {
        Section {
            TextField("名前（空なら行き先の名前）", text: $draft.title)
            if let problem = draft.titleProblem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            urlField
            LinkHintView(hint: draft.urlHint)
        } header: {
            Text("リンク")
        } footer: {
            Text("例: https://www.apple.com/jp/ 、shortcuts:// 。javascript: などの危険な URL は登録できません。")
        }
        Section("記号") {
            SymbolChoiceGrid(selection: $draft.symbolName, tint: draft.tint)
        }
        Section("色") {
            ColorChoiceRow(selection: $draft.tint)
        }
        Section("プレビュー") {
            LinkPreviewRow(draft: draft)
        }
    }

    private var urlField: some View {
        TextField("URL", text: $draft.urlText)
            .keyboardType(.URL)
            .textContentType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}

@MainActor
struct LinkHintView: View {
    let hint: LinkHint?

    var body: some View {
        switch hint {
        case .info(let text):
            Label(text, systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .warning(let text):
            Label(text, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
        case .error(let text):
            Label(text, systemImage: "xmark.octagon")
                .font(.footnote)
                .foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }
}

@MainActor
struct LinkPreviewRow: View {
    let draft: LinkDraft

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            IconTile(symbolName: draft.symbolName, tint: draft.tint, badge: .externalLink, size: DesignTokens.Icon.compactDockSize)
            Text(previewTitle)
                .foregroundStyle(titleStyle)
        }
        .accessibilityElement(children: .combine)
    }

    private var previewTitle: String {
        draft.makeItem(id: "preview")?.title ?? "（URL を入力してください）"
    }

    private var titleStyle: HierarchicalShapeStyle {
        draft.makeItem(id: "preview") == nil ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary
    }
}
