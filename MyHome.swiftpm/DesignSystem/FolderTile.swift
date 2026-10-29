import SwiftUI

/// フォルダのアイコン（F0131）。中の最初の4項目を小さな四角で並べる。枠の大きさは IconTile と同じ
/// （一辺 size + 2 × Icon.badgeInset）なので、ホーム・Dock のどちらに置いても並びが揃う。
@MainActor
struct FolderTile: View {
    let items: [HomeItem]
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * DesignTokens.Icon.cornerRatio, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: size * DesignTokens.Icon.cornerRatio, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            }
            .overlay { preview }
            .frame(width: size, height: size)
            .padding(DesignTokens.Icon.badgeInset)
            .accessibilityHidden(true)
    }

    private var preview: some View {
        let spacing: CGFloat = size * 0.08
        return VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                cell(0)
                cell(1)
            }
            HStack(spacing: spacing) {
                cell(2)
                cell(3)
            }
        }
    }

    @ViewBuilder
    private func cell(_ index: Int) -> some View {
        let side: CGFloat = size * 0.32
        if index < items.count {
            let item: HomeItem = items[index]
            RoundedRectangle(cornerRadius: side * DesignTokens.Icon.cornerRatio, style: .continuous)
                .fill(item.tint.color)
                .overlay {
                    Image(systemName: item.symbolName)
                        .font(.system(size: side * 0.5, weight: .semibold))
                        .foregroundStyle(item.tint.readableForeground.color)
                }
                .frame(width: side, height: side)
        } else {
            Color.clear
                .frame(width: side, height: side)
        }
    }
}

/// 項目の種類に応じたアイコン（通常の項目は IconTile、フォルダは FolderTile）。
@MainActor
struct ItemTile: View {
    let item: HomeItem
    let size: CGFloat

    var body: some View {
        if let children = item.folderItems {
            FolderTile(items: children, size: size)
        } else {
            IconTile(symbolName: item.symbolName, tint: item.tint, badge: item.badge, size: size)
        }
    }
}
