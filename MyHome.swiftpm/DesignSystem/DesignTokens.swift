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
        /// 印がアイコンの右上からはみ出す量。
        static let badgeOffset: CGFloat = 6
        /// アイコンの四方に確保する余白。はみ出した印（と縁取りの線 1pt）も IconTile の枠に含め、
        /// ScrollView のような切り抜く入れ物の端に置かれても切れないようにする。
        static let badgeInset: CGFloat = badgeOffset + 1
    }

    enum Grid {
        static let horizontalPadding: CGFloat = 20
        /// スクロール領域の上下の余白。最上段と最下段がスクロール領域の端に貼り付かないようにする
        /// （印のはみ出し分は IconTile 自身が Icon.badgeInset で確保する）。
        static let verticalPadding: CGFloat = 8
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

    enum Widget {
        static let smallWidth: CGFloat = 170
        /// ウィジェットどうしの間隔。
        static let spacing: CGFloat = 12
        /// 中は小2つ分と、その間の間隔。
        static let mediumWidth: CGFloat = smallWidth * 2 + spacing
        static let height: CGFloat = 170
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
