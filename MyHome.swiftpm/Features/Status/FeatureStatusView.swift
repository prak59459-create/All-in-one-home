import SwiftUI

/// 機能の状況（利用可能 / スタブ / 準備中 / 要調査 / OS の制限）の一覧（F1200、F0971）。
@MainActor
struct FeatureStatusView: View {
    @Environment(\.dismiss) private var dismiss
    private let entries: [FeatureStatusEntry] = FeatureStatusCatalog.entries()

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                FeatureStatusRow(entry: entry)
            }
            .navigationTitle("機能の状況")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@MainActor
struct FeatureStatusRow: View {
    let entry: FeatureStatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
                Text(entry.title)
                Spacer(minLength: DesignTokens.Spacing.small)
                FeatureStateTag(state: entry.state)
            }
            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
struct FeatureStateTag: View {
    let state: FeatureState

    var body: some View {
        Text(state.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.xSmall)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
    }
}
