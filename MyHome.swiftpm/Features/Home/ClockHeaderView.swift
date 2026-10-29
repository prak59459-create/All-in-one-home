import SwiftUI

/// 時計と日付（F0201、F0206、F0207）。TimelineView が1分ごとに中身だけを描き直すので、
/// 時刻の更新でホーム画面全体が再描画されない（F0906）。
@MainActor
struct ClockHeaderView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            ClockFaceView(date: context.date)
        }
    }
}

@MainActor
struct ClockFaceView: View {
    let date: Date
    @Environment(\.homePalette) private var palette
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = DesignTokens.Clock.timeSize

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xSmall) {
            Text(date, format: .dateTime.hour().minute())
                .font(.system(size: timeSize, weight: .thin, design: .rounded))
                .monospacedDigit()
            Text(date, format: .dateTime.month().day().weekday(.wide))
                .font(.title3)
        }
        .foregroundStyle(palette.label.color)
        .accessibilityElement(children: .combine)
    }
}
