import SwiftUI

/// アプリの一覧（ウィジェット型のホーム画面の「アプリ」。追加フェーズ A）。ホーム画面の上に重ねて表示し、外側か「閉じる」で閉じる。
/// ウィジェット型ではアイコンと Dock を出さないので、すべての機能（アプリ）と、ホーム画面にあるリンクはここから開く。
@MainActor
struct AppLibraryOverlay: View {
    @Environment(HomeStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            Button {
                router.closeAppLibrary()
            } label: {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("アプリの一覧を閉じる")
            AppLibraryPanel(links: store.layout.libraryLinks)
                .padding(DesignTokens.Spacing.xLarge)
        }
    }
}

@MainActor
struct AppLibraryPanel: View {
    let links: [HomeItem]
    @Environment(AppRouter.self) private var router

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: DesignTokens.Icon.labelWidth), spacing: DesignTokens.Spacing.medium, alignment: .top)
    ]

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            header
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                    LazyVGrid(columns: columns, spacing: DesignTokens.Grid.rowSpacing) {
                        ForEach(HomeLayout.libraryFeatures, id: \.self) { (feature: AppFeature) in
                            AppLibraryButton(item: DefaultLayout.item(for: feature)) {
                                router.open(feature)
                            }
                        }
                    }
                    if !links.isEmpty {
                        Text("リンク")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        LazyVGrid(columns: columns, spacing: DesignTokens.Grid.rowSpacing) {
                            ForEach(links) { (item: HomeItem) in
                                AppLibraryButton(item: item) {
                                    router.launch(item)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Grid.verticalPadding)
            }
        }
        .padding(DesignTokens.Spacing.large)
        .frame(maxWidth: 720, maxHeight: 640)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("アプリ")
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Text("アプリ")
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                router.closeAppLibrary()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("閉じる")
        }
    }
}

/// 一覧の 1 つ（アイコンと名前）。ホーム画面のアイコンと同じ見た目で、長押しのメニューはない。
@MainActor
struct AppLibraryButton: View {
    let item: HomeItem
    let action: @MainActor () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: DesignTokens.Spacing.xSmall) {
                ItemTile(item: item, size: DesignTokens.Icon.size)
                Text(item.title)
                    .font(.caption)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: DesignTokens.Icon.labelWidth)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(item.title)
        .accessibilityHint(item.accessibilityHint)
    }
}
