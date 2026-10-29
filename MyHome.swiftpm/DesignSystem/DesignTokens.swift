import SwiftUI

/// 余白・角丸・大きさ・動きの値（D1201）。画面ごとに数値を直書きせず、ここから使う。
enum DesignTokens {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 26
    }

    enum Icon {
        static let size: CGFloat = 64
        static let dockSize: CGFloat = 56
        static let compactDockSize: CGFloat = 44
        /// 角丸の半径（一辺に対する比率）。
        static let cornerRatio: CGFloat = 0.225
        /// 記号の大きさ（一辺に対する比率）。
        static let symbolRatio: CGFloat = 0.45
        static let labelWidth: CGFloat = 96
        static let badgeOffset: CGFloat = 6
    }

    enum Grid {
        static let horizontalPadding: CGFloat = 20
        /// スクロール領域の上下の余白。アイコンの印は上に Icon.badgeOffset だけはみ出すので、それより大きくする
        /// （余白がないと最上段の印がスクロール領域の端で切れる。Simulator のスクリーンショットで確認）。
        static let verticalPadding: CGFloat = 12
        static let rowSpacing: CGFloat = 24
    }

    enum Page {
        static let dotSize: CGFloat = 8
        /// 点をタップしやすくするための当たり判定の大きさ。
        static let dotHitSize: CGFloat = 28
    }

    enum Clock {
        static let timeSize: CGFloat = 72
    }

    enum Swatch {
        static let width: CGFloat = 72
        static let height: CGFloat = 96
    }

    enum Motion {
        static let quick: Double = 0.18
        static let standard: Double = 0.3
        static let pressedScale: CGFloat = 0.92
    }
}
