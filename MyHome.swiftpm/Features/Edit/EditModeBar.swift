import SwiftUI

/// 編集モード中に画面上部に出すバー（F0035、F0036）。取り消し・やり直し（F0033、F0034）、ページの管理、
/// 項目の追加、編集の終了。狭いウィンドウでは説明文を省き、ボタンを記号だけにする。
@MainActor
struct EditModeBar: View {
    let pageIndex: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            EditModeBarContent(pageIndex: pageIndex, isCompact: false)
            EditModeBarContent(pageIndex: pageIndex, isCompact: true)
        }
        .padding(.horizontal, DesignTokens.Grid.horizontalPadding)
    }
}

@MainActor
struct EditModeBarContent: View {
    let pageIndex: Int
    let isCompact: Bool
    @Environment(AppRouter.self) private var router
    @Environment(HomeStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            heading
            Spacer(minLength: DesignTokens.Spacing.small)
            barButton("取り消す", symbol: "arrow.uturn.backward", enabled: store.canUndo) {
                store.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            barButton("やり直す", symbol: "arrow.uturn.forward", enabled: store.canRedo) {
                store.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            barButton("ページ", symbol: "rectangle.stack", enabled: true) {
                router.presentPageManager()
            }
            barButton("追加", symbol: "plus", enabled: true) {
                router.presentAddItem(pageIndex: pageIndex)
            }
            Button("完了") {
                router.endEditing()
            }
            .buttonStyle(.borderedProminent)
            .fixedSize()
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    @ViewBuilder
    private var heading: some View {
        if isCompact {
            Image(systemName: "square.and.pencil")
                .font(.headline)
                .accessibilityLabel("ホーム画面を編集中")
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Label("ホーム画面を編集中", systemImage: "square.and.pencil")
                    .font(.headline)
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: 260, alignment: .leading)
        }
    }

    private var hint: String {
        switch settings.homeStyle {
        case .widgets:
            return "ウィジェットをタップすると大きさの変更・移動、− で削除。「追加」でウィジェットを増やせます。"
        case .icons:
            return "長押しして別の項目・フォルダ・ページの点・Dock に重ねると移動、タップで名前や移動先の変更、− で削除。"
        }
    }

    private func barButton(_ title: String, symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if isCompact {
                Label(title, systemImage: symbol)
                    .labelStyle(.iconOnly)
            } else {
                Label(title, systemImage: symbol)
            }
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
        .fixedSize()
    }
}
