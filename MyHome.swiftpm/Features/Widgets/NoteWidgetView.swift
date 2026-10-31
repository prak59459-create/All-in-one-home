import SwiftUI

/// 短いメモ（付箋）。タップして書く（WidgetEditorView）。本格的なメモは Phase 5 のミニアプリ。
@MainActor
struct NoteWidgetView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            Label("付箋", systemImage: "square.and.pencil")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if text.isEmpty {
                Text("タップして書く")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text(text)
                    .font(.callout)
                    .lineLimit(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}
