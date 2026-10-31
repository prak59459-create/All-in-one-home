import SwiftUI

/// タイマーのウィジェット。タイマーの先頭のカウントダウンを表示し、その場で開始・一時停止できる。
/// 動いている間だけ1秒ごとに描き直す。
@MainActor
struct TimerWidgetView: View {
    @Environment(TimerStore.self) private var timers

    var body: some View {
        if let timer = timers.board.countdowns.first {
            if timer.isRunning {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    TimerWidgetFace(timer: timer, now: context.date)
                }
            } else {
                TimerWidgetFace(timer: timer, now: Date())
            }
        } else {
            VStack(alignment: .leading) {
                Label("タイマー", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                Text("タイマーがありません。タップして作れます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

@MainActor
struct TimerWidgetFace: View {
    let timer: CountdownTimer
    let now: Date
    @Environment(TimerStore.self) private var timers

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            Label(timer.label, systemImage: "timer")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(remainingText)
                .font(.system(size: 30, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(timer.isRunning ? "一時停止" : "開始") {
                if timer.isRunning {
                    timers.pause(id: timer.id)
                } else {
                    timers.start(id: timer.id)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var remainingText: String {
        if case .finished = timer.state {
            return "終了"
        }
        return TimeText.clock(timer.remaining(at: now))
    }
}
