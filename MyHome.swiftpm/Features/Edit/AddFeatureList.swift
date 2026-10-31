import SwiftUI

/// アプリ内の機能の追加。ホーム画面にない機能だけを追加でき、状態（準備中など）も表示する。
@MainActor
struct AddFeatureList: View {
    let onAdd: @MainActor (HomeItem) -> Void
    @Environment(HomeStore.self) private var store

    var body: some View {
        Section {
            ForEach(AppFeature.allCases, id: \.self) { feature in
                AddFeatureRow(
                    item: DefaultLayout.item(for: feature),
                    isPlaced: store.layout.location(ofItem: DefaultLayout.item(for: feature).id) != nil,
                    onAdd: onAdd
                )
            }
        } header: {
            Text("アプリ内の機能")
        } footer: {
            Text("削除した機能は、ここからもう一度追加できます。")
        }
    }
}

@MainActor
struct AddFeatureRow: View {
    let item: HomeItem
    let isPlaced: Bool
    let onAdd: @MainActor (HomeItem) -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                IconTile(symbolName: item.symbolName, tint: item.tint, badge: item.badge, size: DesignTokens.Icon.compactDockSize)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                    Text(stateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer()
            if isPlaced {
                Text("配置済み")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button("追加") {
                    onAdd(item)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("\(item.title)を追加")
            }
        }
    }

    private var stateText: String {
        guard case .feature(let feature) = item.action else { return "" }
        return feature.state.label
    }
}
