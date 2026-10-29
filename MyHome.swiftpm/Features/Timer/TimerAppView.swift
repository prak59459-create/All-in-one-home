import SwiftUI

/// タイマー（F0218–F0227、F0237）。複数のカウントダウンと、ストップウォッチ。
/// 動いている時だけ、その行を描き直す。アプリを閉じている間は音を鳴らせない（OS の制限）。
@MainActor
struct TimerAppView: View {
    @Environment(TimerStore.self) private var timers
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(timers.board.countdowns) { timer in
                        CountdownRow(timer: timer)
                    }
                    .onDelete { offsets in
                        remove(at: offsets)
                    }
                    NewCountdownRow()
                } header: {
                    Text("タイマー")
                } footer: {
                    Text("アプリを閉じている間や、画面を消している間は音が鳴りません（iPadOS の制限）。終了時刻は覚えているので、戻った時に正しい残り時間を表示します。")
                }
                Section("ストップウォッチ") {
                    StopwatchPanel()
                }
            }
            .navigationTitle("タイマー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    private func remove(at offsets: IndexSet) {
        let ids: [String] = offsets.map { (index: Int) -> String in timers.board.countdowns[index].id }
        for id in ids {
            timers.removeCountdown(id: id)
        }
    }
}

@MainActor
struct CountdownRow: View {
    let timer: CountdownTimer
    @Environment(TimerStore.self) private var timers

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timer.label)
                if timer.isRunning {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        RemainingText(timer: timer, now: context.date)
                    }
                } else {
                    RemainingText(timer: timer, now: Date())
                }
            }
            Spacer()
            Button(timer.isRunning ? "一時停止" : "開始") {
                if timer.isRunning {
                    timers.pause(id: timer.id)
                } else {
                    timers.start(id: timer.id)
                }
            }
            .buttonStyle(.borderedProminent)
            Button("リセット") {
                timers.reset(id: timer.id)
            }
            .buttonStyle(.bordered)
            .disabled(timer.state == .idle)
        }
    }
}

@MainActor
struct RemainingText: View {
    let timer: CountdownTimer
    let now: Date

    var body: some View {
        Text(text)
            .font(.system(.title, design: .rounded).weight(.light))
            .monospacedDigit()
    }

    private var text: String {
        if case .finished = timer.state {
            return "終了"
        }
        return TimeText.clock(timer.remaining(at: now))
    }
}

/// 新しいカウントダウン（よく使う時間のボタンと、分を指定して作る）。
@MainActor
struct NewCountdownRow: View {
    @Environment(TimerStore.self) private var timers
    @State private var minutes: Int = 10
    @State private var label: String = ""
    @State private var failure: String?

    private let presets: [Int] = [1, 3, 5, 10, 25]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack {
                ForEach(presets, id: \.self) { value in
                    Button("\(value)分") {
                        add(minutes: value, label: "\(value)分")
                    }
                    .buttonStyle(.bordered)
                }
            }
            HStack {
                TextField("名前（任意）", text: $label)
                Stepper("\(minutes) 分", value: $minutes, in: 1...1440)
                    .fixedSize()
                Button("追加") {
                    add(minutes: minutes, label: label)
                    label = ""
                }
                .buttonStyle(.borderedProminent)
            }
            if let failure {
                Text(failure).font(.footnote).foregroundStyle(.red)
            }
        }
    }

    private func add(minutes: Int, label: String) {
        do {
            try timers.addCountdown(label: label, duration: TimeInterval(minutes * 60))
            failure = nil
        } catch let error as TimerEditError {
            failure = error.message
        } catch {
            failure = "追加できませんでした。"
        }
    }
}

@MainActor
struct StopwatchPanel: View {
    @Environment(TimerStore.self) private var timers

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            if timers.board.stopwatch.isRunning {
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    elapsedText(at: context.date)
                }
            } else {
                elapsedText(at: Date())
            }
            HStack {
                Button(timers.board.stopwatch.isRunning ? "一時停止" : "開始") {
                    if timers.board.stopwatch.isRunning {
                        timers.pauseStopwatch()
                    } else {
                        timers.startStopwatch()
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("ラップ") { timers.lapStopwatch() }
                    .buttonStyle(.bordered)
                    .disabled(!timers.board.stopwatch.isRunning)
                Button("リセット") { timers.resetStopwatch() }
                    .buttonStyle(.bordered)
            }
            ForEach(timers.board.stopwatch.laps.indices.reversed(), id: \.self) { index in
                Text("ラップ \(index + 1)  \(TimeText.stopwatch(timers.board.stopwatch.laps[index]))")
                    .font(.footnote.monospacedDigit())
            }
        }
    }

    private func elapsedText(at date: Date) -> some View {
        Text(TimeText.stopwatch(timers.board.stopwatch.elapsed(at: date)))
            .font(.system(size: 44, weight: .light, design: .rounded))
            .monospacedDigit()
    }
}
