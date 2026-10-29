import SwiftUI

/// 開いたフォルダ（F0121、F0126–F0128、F0144）。ホーム画面の上に重ねて表示し、外側か「閉じる」で閉じる。
/// 中の項目はホーム画面と同じ HomeItemButton なので、タップで開く・編集中の並べ替えや取り出しも同じ操作でできる。
@MainActor
struct FolderOverlayView: View {
    let folderID: String
    @Environment(HomeStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let folder = store.layout.item(id: folderID), let items = folder.folderItems {
            ZStack {
                Button {
                    router.closeFolder()
                } label: {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("フォルダを閉じる")
                FolderPanel(folder: folder, items: items)
                    .padding(DesignTokens.Spacing.xLarge)
            }
        } else {
            // 解除・空になったなどでフォルダがなくなった
            Color.clear
                .onAppear {
                    router.closeFolder()
                }
        }
    }
}

@MainActor
struct FolderPanel: View {
    let folder: HomeItem
    let items: [HomeItem]

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: DesignTokens.Icon.labelWidth), spacing: DesignTokens.Spacing.medium, alignment: .top)
    ]

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            FolderHeader(folder: folder)
            ScrollView(.vertical) {
                LazyVGrid(columns: columns, spacing: DesignTokens.Grid.rowSpacing) {
                    ForEach(items) { item in
                        HomeItemButton(item: item)
                    }
                }
                .padding(.vertical, DesignTokens.Grid.verticalPadding)
            }
        }
        .padding(DesignTokens.Spacing.large)
        .frame(maxWidth: 640, maxHeight: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("フォルダ「\(folder.title)」")
    }
}

@MainActor
struct FolderHeader: View {
    let folder: HomeItem
    @Environment(AppRouter.self) private var router
    @Environment(\.homePalette) private var palette

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Text(folder.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.label.color)
                .lineLimit(1)
            Spacer()
            if router.isEditing {
                Button("名前を変更") {
                    router.presentItemEditor(for: folder)
                }
                .buttonStyle(.bordered)
            }
            Button {
                router.closeFolder()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
        }
    }
}
