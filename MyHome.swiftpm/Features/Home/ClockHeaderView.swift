import SwiftUI

/// 時計と日付（F0201、F0206、F0207）。TimelineView が1分ごと（秒を表示する時は1秒ごと。F0203）に中身だけを描き直すので、
/// 時刻の更新でホーム画面全体が再描画されない（F0906）。12 時間 / 24 時間の表示は端末の設定に従う（F0204、F0205）。
@MainActor
struct ClockHeaderView: View {
    var showsSeconds: Bool = false

    var body: some View {
        if showsSeconds {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ClockFaceView(date: context.date, showsSeconds: true)
            }
        } else {
            TimelineView(.everyMinute) { context in
                ClockFaceView(date: context.date, showsSeconds: false)
            }
        }
    }
}

@MainActor
struct ClockFaceView: View {
    let date: Date
    let showsSeconds: Bool
    @Environment(\.homePalette) private var palette
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = DesignTokens.Clock.timeSize

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xSmall) {
            Text(date, format: timeFormat)
                .font(.system(size: timeSize, weight: .thin, design: .rounded))
                .monospacedDigit()
            Text(date, format: .dateTime.month().day().weekday(.wide))
                .font(.title3)
        }
        .foregroundStyle(palette.label.color)
        .modifier(LegibleOnWallpaper())
        .accessibilityElement(children: .combine)
    }

    private var timeFormat: Date.FormatStyle {
        showsSeconds ? Date.FormatStyle.dateTime.hour().minute().second() : Date.FormatStyle.dateTime.hour().minute()
    }
}
