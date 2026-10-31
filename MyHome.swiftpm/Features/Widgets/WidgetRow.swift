import SwiftUI

/// ページ上部のウィジェット（F0161–F0168）。横に並べ、入りきらなければ横にスクロールする。
/// iPadOS のホーム画面のウィジェット（WidgetKit）ではなく、MyHome の中だけで表示する。
@MainActor
struct WidgetRow: View {
    let widgets: [HomeWidget]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: DesignTokens.Widget.spacing) {
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
    /// 置ける幅。中のウィジェットが入らない時（Slide Over など）は、小の大きさで表示する。
    var maximumWidth: CGFloat = .infinity
    @Environment(AppRouter.self) private var router
    @Environment(HomeStore.self) private var store

    var body: some View {
        WidgetContent(widget: widget, size: displaySize)
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
            .modifier(WidgetContextMenu(widget: widget))
            .modifier(WidgetAccessibility(widget: widget, isEditing: router.isEditing, onActivate: tap))
            .accessibilityActions {
                if router.isEditing {
                    Button("設定") { router.presentWidgetEditor(widget) }
                    Button("前に移動") { try? store.moveWidget(id: widget.id, by: -1) }
                    Button("後ろに移動") { try? store.moveWidget(id: widget.id, by: 1) }
                    Button("削除") { router.requestWidgetRemoval(widget) }
                }
            }
    }

    private var displaySize: WidgetSize {
        widget.size == .medium && maximumWidth >= DesignTokens.Widget.mediumWidth ? .medium : .small
    }

    private var width: CGFloat {
        displaySize == .medium ? DesignTokens.Widget.mediumWidth : DesignTokens.Widget.smallWidth
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
        case .app(let feature):
            router.open(feature)
        case .clock, .calendar:
            break
        }
    }
}

/// 編集中でない時の長押しメニュー（編集モードへの切り替え・設定・削除）。
@MainActor
struct WidgetContextMenu: ViewModifier {
    let widget: HomeWidget
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        if router.isEditing {
            content
        } else {
            content.contextMenu {
                Button {
                    router.beginEditing()
                } label: {
                    Label("ホーム画面を編集", systemImage: "square.and.pencil")
                }
                Button {
                    router.presentWidgetEditor(widget)
                } label: {
                    Label("ウィジェットを設定", systemImage: "slider.horizontal.3")
                }
                Button(role: .destructive) {
                    router.requestWidgetRemoval(widget)
                } label: {
                    Label("削除", systemImage: "minus.circle")
                }
            }
        }
    }
}

/// VoiceOver での読み上げ。アプリのウィジェットは 1 つのボタンとして中身ごと読み上げ、ダブルタップで開く。
/// それ以外（時計・カレンダーなど）は、中の要素を順に読む。
@MainActor
struct WidgetAccessibility: ViewModifier {
    let widget: HomeWidget
    let isEditing: Bool
    let onActivate: @MainActor () -> Void

    func body(content: Content) -> some View {
        if let feature = widget.kind.feature {
            content
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(isEditing ? "ウィジェットの設定を開きます" : "\(feature.title)を開きます")
                .accessibilityAction {
                    onActivate()
                }
        } else {
            content
                .accessibilityElement(children: .contain)
                .accessibilityLabel("ウィジェット: \(widget.kind.title)")
        }
    }
}

@MainActor
struct WidgetContent: View {
    let widget: HomeWidget
    let size: WidgetSize

    var body: some View {
        switch widget.kind {
        case .clock(let style):
            ClockWidgetView(style: style, size: size)
        case .calendar:
            CalendarWidgetView(size: size)
        case .note(let text):
            NoteWidgetView(text: text)
        case .timer:
            TimerWidgetView()
        case .app(let feature):
            AppWidgetView(feature: feature, size: size)
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
