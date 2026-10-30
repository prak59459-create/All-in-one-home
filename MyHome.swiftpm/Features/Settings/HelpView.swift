import SwiftUI

/// 使い方と困った時（F0963–F0972、F0998、F0999）。見出しと手順の文で探せる。
@MainActor
struct HelpView: View {
    @State private var query: String = ""

    var body: some View {
        let sections: [HelpSection] = HelpCatalog.search(query)
        List {
            if sections.isEmpty {
                Text("「\(query)」に当てはまる説明はありません。")
                    .foregroundStyle(.secondary)
            }
            ForEach(sections) { (section: HelpSection) in
                Section(section.title) {
                    ForEach(section.topics) { (topic: HelpTopic) in
                        HelpTopicRow(topic: topic, isExpanded: !query.isEmpty)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "ヘルプを検索")
        .navigationTitle("使い方と困った時")
    }
}

@MainActor
struct HelpTopicRow: View {
    let topic: HelpTopic
    let isExpanded: Bool
    @State private var isOpen: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: expansion) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                ForEach(topic.steps, id: \.self) { (step: String) in
                    Text(step)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xSmall)
        } label: {
            Label(topic.title, systemImage: topic.symbol)
        }
    }

    /// 検索している間は開いて見せる。
    private var expansion: Binding<Bool> {
        Binding<Bool>(
            get: { isOpen || isExpanded },
            set: { (open: Bool) in
                isOpen = open
            }
        )
    }
}
