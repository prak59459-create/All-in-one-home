import SwiftUI

/// 設定 → このアプリについて（OS の許可・通信・保存先・出典とライセンス）。内容は AboutCatalog（Core）。
@MainActor
struct AboutView: View {
    var body: some View {
        Form {
            ForEach(AboutCatalog.sections()) { (section: AboutSection) in
                Section {
                    ForEach(section.items) { (item: AboutItem) in
                        AboutItemRow(item: item)
                    }
                } header: {
                    Text(section.title)
                } footer: {
                    Text(section.footer)
                }
            }
        }
        .navigationTitle("このアプリについて")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
struct AboutItemRow: View {
    let item: AboutItem

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
            Text(item.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let link = item.link {
                ExternalLinkButton(title: item.linkTitle ?? link, address: link)
                    .font(.callout)
            }
        }
        .padding(.vertical, 2)
    }
}
