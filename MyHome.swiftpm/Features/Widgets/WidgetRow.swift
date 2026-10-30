import SwiftUI

/// ページ上部のウィジェット（F0161–F0168）。横に並べ、入りきらなければ横にスクロールする。
/// iPadOS のホーム画面のウィジェット（WidgetKit）ではなく、MyHome の中だけで表示する。
@MainActor
struct WidgetRow: View {
    let widgets: [HomeWidget]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(widgets) { widget in
                    WidgetCard(widget: widget)
                }
            }
            .padding(.horizontal, DesignTokens.Grid.horizontalPadding)
            .padding(.vertical, DesignTokens.Spacing.small)
        }
    }
}

/// ウィジェット1つ。編集中は左上の − で削除、タップで設定。メモはいつでもタップで書ける。タイマーはタップでタイマーを開く。
@MainActor
struct WidgetCard: View {
    let widget: HomeWidget
    @Environment(AppRouter.self) private var router
    @Environment(HomeStore.self) private var store

    var body: some View {
        WidgetContent(widget: widget)
            // 大きさの決まったカードなので、文字は iPad のホーム画面のウィジェットと同じく xxxLarge で止める
            // （Phase 8 の起動テストで、いちばん大きな文字では月の名前やメモが 1〜2 文字しか見えなかった）
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(DesignTokens.Spacing.medium)
            .frame(width: width, height: DesignTokens.Widget.height)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
            .overlay(alignment: .topLeading) {
                if router.isEditing {
                    // 中の文字（カレンダーの月など）に重ならないよう、角に寄せる。
                    // はみ出しは 3pt で、WidgetRow の上下の余白（8pt）に収まるので切れない
                    RemoveWidgetButton(widget: widget)
                        .offset(x: -8, y: -8)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
            .onTapGesture {
                tap()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("ウィジェット: \(widget.kind.title)")
            .accessibilityActions {
                if router.isEditing {
                    Button("設定") { router.presentWidgetEditor(widget) }
                    Button("前に移動") { try? store.moveWidget(id: widget.id, by: -1) }
                    Button("後ろに移動") { try? store.moveWidget(id: widget.id, by: 1) }
                    Button("削除") { router.requestWidgetRemoval(widget) }
                }
            }
    }

    private var width: CGFloat {
        widget.size == .medium ? DesignTokens.Widget.mediumWidth : DesignTokens.Widget.smallWidth
    }

    private func tap() {
        if router.isEditing {
            router.presentWidgetEditor(widget)
            return
        }
        switch widget.kind {
        case .note:
            router.presentWidgetEditor(widget)
        case .timer:
            router.sheet = .feature(.timer)
        case .clock, .calendar:
            break
        }
    }
}

@MainActor
struct WidgetContent: View {
    let widget: HomeWidget

    var body: some View {
        switch widget.kind {
        case .clock(let style):
            ClockWidgetView(style: style, size: widget.size)
        case .calendar:
            CalendarWidgetView(size: widget.size)
        case .note(let text):
            NoteWidgetView(text: text)
        case .timer:
            TimerWidgetView()
        }
    }
}

@MainActor
struct RemoveWidgetButton: View {
    let widget: HomeWidget
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.requestWidgetRemoval(widget)
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white, Color.black.opacity(0.75))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("ウィジェット「\(widget.kind.title)」を削除")
    }
}
