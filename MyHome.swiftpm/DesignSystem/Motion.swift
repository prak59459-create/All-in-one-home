import SwiftUI

private struct MotionLevelKey: EnvironmentKey {
    static let defaultValue: MotionLevel = .full
}

extension EnvironmentValues {
    /// 動きの量（F0671、F0672、F0674）。設定と端末の「視差効果を減らす」から MotionRoot が決めて配下へ渡す。
    var motionLevel: MotionLevel {
        get { self[MotionLevelKey.self] }
        set { self[MotionLevelKey.self] = newValue }
    }
}

/// アニメーションはここから取る（どの画面でも、設定と「視差効果を減らす」に同じように従うため。F0677）。
enum MotionStyle {
    /// 状態の切り替え（フォルダの開閉・編集モード）。減らす設定では短いフェードだけ。
    static func standard(_ level: MotionLevel) -> Animation? {
        switch level {
        case .full: return .spring(response: 0.32, dampingFraction: 0.86)
        case .reduced: return .easeInOut(duration: DesignTokens.Motion.quick)
        case .none: return nil
        }
    }

    /// ページの移動など、画面が横に動くもの。減らす設定では動かさずに切り替える。
    static func movement(_ level: MotionLevel) -> Animation? {
        level.allowsMovement ? .easeInOut(duration: DesignTokens.Motion.standard) : nil
    }

    /// 出入りの演出（拡大しながら現れる）。減らす設定ではフェードだけ、オフなら何もしない。
    static func appear(_ level: MotionLevel) -> AnyTransition {
        switch level {
        case .full: return AnyTransition.scale(scale: 0.92).combined(with: .opacity)
        case .reduced: return AnyTransition.opacity
        case .none: return AnyTransition.identity
        }
    }
}

/// アプリの一番外側に置き、設定（SettingsStore）から動きの量と文字の大きさを配下（シートを含む）へ渡す。
/// HomeScreen の外側に置くので、HomeScreen 自身のアニメーションも同じ値を使える。
@MainActor
struct AccessibilityRoot<Content: View>: View {
    @Environment(SettingsStore.self) private var settings
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .modifier(MotionRoot(motion: settings.motion, textSize: settings.textSize))
    }
}

/// 設定と端末の「視差効果を減らす」から動きの量を決め、文字の大きさの設定と一緒に配下へ渡す。
@MainActor
struct MotionRoot: ViewModifier {
    let motion: MotionPreference
    let textSize: TextSizePreference
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let level: MotionLevel = MotionLevel.resolve(motion, systemReduceMotion: reduceMotion)
        content
            .environment(\.motionLevel, level)
            .modifier(TextSizeOverride(preference: textSize))
    }
}

/// このアプリの中だけの文字の大きさ（F0978）。「端末の設定に合わせる」の時は全部の大きさを許す（何もしないのと同じ）。
/// 設定を変えても View の作り直しにならないよう、いつも同じ修飾子で範囲だけを変える
/// （作り直すと、開いている設定のシートが閉じ、表示中のページも先頭に戻るため）。
@MainActor
struct TextSizeOverride: ViewModifier {
    let preference: TextSizePreference

    func body(content: Content) -> some View {
        content.dynamicTypeSize(TextSizeOverride.range(for: preference))
    }

    static func range(for preference: TextSizePreference) -> ClosedRange<DynamicTypeSize> {
        guard let size = dynamicTypeSize(for: preference) else {
            return DynamicTypeSize.xSmall...DynamicTypeSize.accessibility5
        }
        return size...size
    }

    static func dynamicTypeSize(for preference: TextSizePreference) -> DynamicTypeSize? {
        switch preference {
        case .system: return nil
        case .small: return .small
        case .standard: return .large
        case .large: return .xLarge
        case .extraLarge: return .xxxLarge
        case .largest: return .accessibility2
        }
    }
}
