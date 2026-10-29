import SwiftUI

/// 編集モード中に画面上部に出すバー（F0035、F0036）。項目の追加と、編集の終了を行う。
@MainActor
struct EditModeBar: View {
    let pageIndex: Int
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Label("ホーム画面を編集中", systemImage: "square.and.pencil")
                    .font(.headline)
                Text("アイコンを長押しして別のアイコンに重ねると並べ替え、左上の − で削除します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DesignTokens.Spacing.small)
            Button {
                router.presentAddItem(pageIndex: pageIndex)
            } label: {
                Label("追加", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            Button("完了") {
                router.endEditing()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
        .padding(.horizontal, DesignTokens.Grid.horizontalPadding)
    }
}
