import SwiftUI

/// 押している間だけ少し縮める（F0658）。Reduce Motion が有効なら縮めずに薄くするだけにする（F0674）。
@MainActor
struct IconPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed: Bool = configuration.isPressed
        let shrinks: Bool = pressed && !reduceMotion
        let scale: CGFloat = shrinks ? DesignTokens.Motion.pressedScale : 1
        let opacity: Double = pressed ? 0.75 : 1
        let animation: Animation? = reduceMotion ? nil : .easeOut(duration: DesignTokens.Motion.quick)
        return configuration.label
            .scaleEffect(scale)
            .opacity(opacity)
            .animation(animation, value: pressed)
    }
}
