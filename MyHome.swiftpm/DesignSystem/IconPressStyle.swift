import SwiftUI

/// 押している間だけ少し縮める（F0658）。動きを減らす設定（端末の「視差効果を減らす」を含む）では縮めずに薄くするだけ、
/// オフでは変化をアニメーションしない（F0672、F0674）。
@MainActor
struct IconPressStyle: ButtonStyle {
    @Environment(\.motionLevel) private var motion

    func makeBody(configuration: Configuration) -> some View {
        let pressed: Bool = configuration.isPressed
        let shrinks: Bool = pressed && motion.allowsMovement
        let scale: CGFloat = shrinks ? DesignTokens.Motion.pressedScale : 1
        let opacity: Double = pressed ? 0.75 : 1
        let animation: Animation? = motion.allowsFade ? .easeOut(duration: DesignTokens.Motion.quick) : nil
        return configuration.label
            .scaleEffect(scale)
            .opacity(opacity)
            .animation(animation, value: pressed)
    }
}
