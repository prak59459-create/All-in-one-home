import SwiftUI

/// 1ページ分のアイコングリッド（F0001、F0901）。使える幅から列数を決め（F0005、F0006）、
/// 項目が多い時は縦にスクロールして表示が破綻しないようにする。
@MainActor
struct HomePageGridView: View {
    let page: HomePage
    let pageIndex: Int

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                pageContent(width: proxy.size.width)
            }
        }
    }

    @ViewBuilder
    private func pageContent(width: CGFloat) -> some View {
        if page.items.isEmpty {
            EmptyPageView(pageIndex: pageIndex)
                .frame(width: width)
                .padding(.top, DesignTokens.Spacing.xLarge)
        } else {
            LazyVGrid(columns: columns(for: width), spacing: DesignTokens.Grid.rowSpacing) {
                ForEach(page.items) { item in
                    HomeItemButton(item: item)
                }
            }
            .padding(.horizontal, DesignTokens.Grid.horizontalPadding)
            .padding(.vertical, DesignTokens.Grid.verticalPadding)
        }
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        let padding: CGFloat = DesignTokens.Grid.horizontalPadding * 2
        let available: Double = Double(width - padding)
        let metrics: GridMetrics = .standard
        let count: Int = metrics.columnCount(forWidth: available)
        let item = GridItem(.flexible(), spacing: CGFloat(metrics.spacing), alignment: .top)
        return Array(repeating: item, count: count)
    }
}

/// 項目がないページの説明と、追加の入口（F0988、F0041）。
@MainActor
struct EmptyPageView: View {
    let pageIndex: Int
    @Environment(\.homePalette) private var palette
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            VStack(spacing: DesignTokens.Spacing.small) {
                Image(systemName: "square.dashed")
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text("このページには項目がありません")
                    .font(.headline)
            }
            .foregroundStyle(palette.label.color)
            .accessibilityElement(children: .combine)
            Button {
                router.beginEditing()
                router.presentAddItem(pageIndex: pageIndex)
            } label: {
                Label("項目を追加", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .multilineTextAlignment(.center)
    }
}
