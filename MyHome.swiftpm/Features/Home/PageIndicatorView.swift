import SwiftUI

/// 現在のページを示す点（F0009）。点のタップ、または VoiceOver の上下スワイプでページを移動できる。
/// 編集中は、ドラッグした項目を点に重ねるとそのページを表示し、離すとそのページの末尾へ移す（F0147）。
/// ページが1枚の時は高さだけを確保して表示しない（編集中は移動先として表示する）。
@MainActor
struct PageIndicatorView: View {
    let count: Int
    @Binding var selection: Int
    @Environment(\.homePalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(HomeStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                dot(index: index)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .accessibilityHidden(!isVisible)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAdjustableAction { direction in
            adjust(direction)
        }
    }

    private var isVisible: Bool {
        count > 1 || router.isEditing
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
            .dropDestination(for: String.self) { droppedIDs, _ in
                moveDropped(droppedIDs, toPage: index)
            } isTargeted: { targeted in
                if targeted {
                    select(index)
                }
            }
    }

    private func moveDropped(_ droppedIDs: [String], toPage index: Int) -> Bool {
        guard let movingID = droppedIDs.first else { return false }
        return DropMover.perform(store: store, router: router) { store in
            try store.move(itemID: movingID, to: .page(index))
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
