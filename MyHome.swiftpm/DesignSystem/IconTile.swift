import SwiftUI

/// ホーム画面と Dock で共通のアイコン。色・記号と、種類の印（外部リンク / スタブ / 準備中）を表示する。
/// 枠の大きさは一辺 size + 2 × Icon.badgeInset。印のはみ出し分を含むので、どの入れ物に置いても印は切れない
/// （iPad で、グリッド最上段の印がスクロール領域の上端で切れていた）。
@MainActor
struct IconTile: View {
    let symbolName: String
    let tint: RGBAColor
    let badge: HomeItemBadge?
    let size: CGFloat
    /// アイコンの画像（Phase 4）。あれば記号の代わりに表示する（F0047）。
    var image: UIImage? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tint.color)
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .frame(width: size, height: size)
            .overlay(alignment: .topTrailing) { badgeView }
            .padding(DesignTokens.Icon.badgeInset)
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else {
            ZStack {
                highlight
                symbol
            }
        }
    }

    private var cornerRadius: CGFloat {
        size * DesignTokens.Icon.cornerRatio
    }

    private var highlight: some View {
        let gradient = LinearGradient(colors: [Color.white.opacity(0.22), Color.clear], startPoint: .top, endPoint: .center)
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(gradient)
    }

    private var symbol: some View {
        let symbolSize: CGFloat = size * DesignTokens.Icon.symbolRatio
        return Image(systemName: symbolName)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(tint.readableForeground.color)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var badgeView: some View {
        if let badge {
            IconBadgeView(badge: badge)
                .offset(x: DesignTokens.Icon.badgeOffset, y: -DesignTokens.Icon.badgeOffset)
        }
    }
}

/// 項目の種類を示す小さな印。色だけに頼らず、文字か記号でも示す（F0980）。
/// 読み上げは HomeItemButton の accessibilityHint で行うため、ここでは読み上げ対象から外す。
@MainActor
struct IconBadgeView: View {
    let badge: HomeItemBadge

    var body: some View {
        content
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, DesignTokens.Spacing.xSmall)
            .padding(.vertical, 2)
            .background(Capsule().fill(badge.fill.color))
            .overlay { Capsule().stroke(Color.white.opacity(0.85), lineWidth: 1) }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let text = badge.text {
            Text(text)
        } else {
            Image(systemName: "arrow.up.right")
        }
    }
}

@MainActor
struct IconTile_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: DesignTokens.Spacing.large) {
            IconTile(symbolName: "swift", tint: RGBAColor(hex: 0xF05138), badge: .externalLink, size: DesignTokens.Icon.size)
            IconTile(symbolName: "sparkles", tint: RGBAColor(hex: 0x7C3AED), badge: .stub, size: DesignTokens.Icon.size)
            IconTile(symbolName: "timer", tint: RGBAColor(hex: 0xEF4444), badge: .planned, size: DesignTokens.Icon.size)
        }
        .padding()
    }
}
