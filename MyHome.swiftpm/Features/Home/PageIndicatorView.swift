import SwiftUI

/// 現在のページを示す点（F0009）。点のタップ、または VoiceOver の上下スワイプでページを移動できる。
/// ページが1枚の時は高さだけを確保して表示しない。
@MainActor
struct PageIndicatorView: View {
    let count: Int
    @Binding var selection: Int
    @Environment(\.homePalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                dot(index: index)
            }
        }
        .opacity(count > 1 ? 1 : 0)
        .accessibilityHidden(count <= 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAdjustableAction { direction in
            adjust(direction)
        }
    }

    private var accessibilityText: String {
        "ページ \(selection + 1) / \(count)"
    }

    private func dot(index: Int) -> some View {
        let isCurrent: Bool = index == selection
        let fill: Color = isCurrent ? palette.accent.color : palette.label.color.opacity(0.35)
        return Circle()
            .fill(fill)
            .frame(width: DesignTokens.Page.dotSize, height: DesignTokens.Page.dotSize)
            .frame(width: DesignTokens.Page.dotHitSize, height: DesignTokens.Page.dotHitSize)
            .contentShape(Rectangle())
            .onTapGesture {
                select(index)
            }
    }

    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment:
            select(selection + 1)
        case .decrement:
            select(selection - 1)
        @unknown default:
            break
        }
    }

    private func select(_ index: Int) {
        guard count > 0 else { return }
        let clamped: Int = min(max(index, 0), count - 1)
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: DesignTokens.Motion.standard)
        withAnimation(animation) {
            selection = clamped
        }
    }
}
