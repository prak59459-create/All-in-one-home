import SwiftUI

/// ウィジェット型のホーム画面のページ（追加フェーズ A）。横スワイプで切り替える（ページ番号は PageIndicatorView と共有）。
/// アイコン（項目）と Dock は表示しない。アプリは下の「アプリ」から、ウィジェットからも開く。
@MainActor
struct WidgetPagesView: View {
    let pages: [HomePage]
    @Binding var selection: Int

    var body: some View {
        TabView(selection: $selection) {
            ForEach(pages.indices, id: \.self) { (index: Int) in
                WidgetPageView(page: pages[index], pageIndex: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

/// 1 ページ分のウィジェット。左上から順に並べ、入りきらなければ次の行へ送る。多い時は縦にスクロールする。
/// 幅が中のウィジェットより狭い時（Slide Over など）は、中も小の大きさで表示する。
@MainActor
struct WidgetPageView: View {
    let page: HomePage
    let pageIndex: Int

    var body: some View {
        GeometryReader { (proxy: GeometryProxy) in
            let available: CGFloat = max(proxy.size.width - DesignTokens.Grid.horizontalPadding * 2, 0)
            ScrollView(.vertical) {
                content(available: available)
                    // 編集中の − は左上に 8pt はみ出すので、その分の余白を上下に取る
                    .padding(.vertical, DesignTokens.Spacing.small)
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func content(available: CGFloat) -> some View {
        if page.widgets.isEmpty {
            EmptyWidgetPageView(pageIndex: pageIndex)
                .padding(.top, DesignTokens.Spacing.xLarge)
                .padding(.horizontal, DesignTokens.Grid.horizontalPadding)
        } else {
            WidgetFlowLayout(spacing: DesignTokens.Widget.spacing) {
                ForEach(page.widgets) { (widget: HomeWidget) in
                    WidgetCard(widget: widget, maximumWidth: available)
                }
            }
        }
    }
}

/// WidgetFlow の並べ方で置く。並べた全体は中央に寄せ、各行は左に揃える。
struct WidgetFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let available: CGFloat = proposal.width ?? .infinity
        let flow: WidgetFlow = arrange(subviews, available: available)
        let width: CGFloat = available.isFinite ? available : CGFloat(flow.width)
        return CGSize(width: width, height: CGFloat(flow.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let flow: WidgetFlow = arrange(subviews, available: bounds.width)
        let left: CGFloat = bounds.minX + max((bounds.width - CGFloat(flow.width)) / 2, 0)
        for (index, frame) in flow.frames.enumerated() {
            let origin = CGPoint(x: left + CGFloat(frame.x), y: bounds.minY + CGFloat(frame.y))
            let size = ProposedViewSize(width: CGFloat(frame.width), height: CGFloat(frame.height))
            subviews[index].place(at: origin, anchor: .topLeading, proposal: size)
        }
    }

    private func arrange(_ subviews: Subviews, available: CGFloat) -> WidgetFlow {
        let sizes: [(width: Double, height: Double)] = subviews.map { (subview: LayoutSubview) -> (width: Double, height: Double) in
            let size: CGSize = subview.sizeThatFits(.unspecified)
            return (width: Double(size.width), height: Double(size.height))
        }
        return WidgetFlow(sizes: sizes, availableWidth: Double(available), spacing: Double(spacing))
    }
}

/// ウィジェットがないページの説明と、追加の入口。
@MainActor
struct EmptyWidgetPageView: View {
    let pageIndex: Int
    @Environment(\.homePalette) private var palette
    @Environment(AppRouter.self) private var router
    @Environment(HomeStore.self) private var store
    @State private var failure: String?

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            VStack(spacing: DesignTokens.Spacing.small) {
                Image(systemName: "square.dashed")
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text("このページにはウィジェットがありません")
                    .font(.headline)
            }
            .foregroundStyle(palette.label.color)
            .modifier(LegibleOnWallpaper())
            .accessibilityElement(children: .combine)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DesignTokens.Spacing.medium) {
                    buttons
                }
                VStack(spacing: DesignTokens.Spacing.small) {
                    buttons
                }
            }
            if let failure {
                Text(failure)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var buttons: some View {
        Button {
            addRecommended()
        } label: {
            Label("おすすめを追加", systemImage: "sparkles")
        }
        .buttonStyle(.borderedProminent)
        Button {
            router.beginEditing()
            router.presentAddItem(pageIndex: pageIndex)
        } label: {
            Label("ウィジェットを選ぶ", systemImage: "plus")
        }
        .buttonStyle(.bordered)
    }

    private func addRecommended() {
        do {
            if try store.addRecommendedWidgets(toPage: pageIndex) == 0 {
                failure = "おすすめのウィジェットは、もう全部どこかのページにあります。"
            }
        } catch let error as LayoutEditError {
            failure = error.message
        } catch {
            failure = "追加できませんでした。"
        }
    }
}

/// ウィジェット型のホーム画面の下のバー（Dock の代わり）。アプリの一覧と、編集の入口。
@MainActor
struct WidgetHomeBar: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Button {
                router.showAppLibrary()
            } label: {
                Label("アプリ", systemImage: "square.grid.2x2.fill")
                    .padding(.horizontal, DesignTokens.Spacing.small)
            }
            Button {
                router.beginEditing()
            } label: {
                Label("編集", systemImage: "square.and.pencil")
                    .padding(.horizontal, DesignTokens.Spacing.small)
            }
        }
        .font(.headline)
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(DesignTokens.Spacing.small)
        .background(.regularMaterial, in: Capsule())
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}
