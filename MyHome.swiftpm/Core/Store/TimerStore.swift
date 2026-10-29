import Foundation
import Observation

/// タイマーとストップウォッチ（F0218–F0227）。状態が変わった時だけ保存を予約する（毎秒は保存しない）。
/// 実行中のタイマーが終わる時刻に合わせて1回だけ起き、「終了」にして onFinish を呼ぶ（画面側で音を鳴らす）。
@MainActor
@Observable
final class TimerStore {
    private(set) var board: TimerBoard
    @ObservationIgnored var onChange: (@MainActor () -> Void)?
    /// タイマーが終わった時（アプリを開いている間だけ。裏に回っている間は OS が止めるので呼べない）。
    @ObservationIgnored var onFinish: (@MainActor (CountdownTimer) -> Void)?
    @ObservationIgnored private var wakeTask: Task<Void, Never>?
    @ObservationIgnored private let clock: @Sendable () -> Date

    init(board: TimerBoard = .initial(), clock: @escaping @Sendable () -> Date = { Date() }) {
        self.board = board
        self.clock = clock
    }

    var now: Date {
        clock()
    }

    func addCountdown(label: String, duration: TimeInterval) throws {
        guard board.countdowns.count < TimerLimits.maximumCountdowns else { throw TimerEditError.limitReached }
        let trimmed: String = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(TimerLimits.maximumLabelLength))
        let name: String = trimmed.isEmpty ? TimeText.clock(TimerLimits.clampedDuration(duration)) : trimmed
        let timer = CountdownTimer(id: "timer.\(UUID().uuidString.lowercased())", label: name, duration: duration)
        update { board in board.countdowns.append(timer) }
    }

    func removeCountdown(id: String) {
        update { board in board.countdowns.removeAll { (timer: CountdownTimer) -> Bool in timer.id == id } }
    }

    func start(id: String) {
        let time: Date = now
        updateTimer(id: id) { timer in timer.start(at: time) }
    }

    func pause(id: String) {
        let time: Date = now
        updateTimer(id: id) { timer in timer.pause(at: time) }
    }

    func reset(id: String) {
        updateTimer(id: id) { timer in timer.reset() }
    }

    func startStopwatch() {
        let time: Date = now
        update { board in board.stopwatch.start(at: time) }
    }

    func pauseStopwatch() {
        let time: Date = now
        update { board in board.stopwatch.pause(at: time) }
    }

    func lapStopwatch() {
        let time: Date = now
        update { board in board.stopwatch.lap(at: time) }
    }

    func resetStopwatch() {
        update { board in board.stopwatch.reset() }
    }

    /// 終了時刻を過ぎたタイマーを「終了」にする（アプリが前面に戻った時と、起きる時刻に呼ぶ）。
    func refresh() {
        let time: Date = now
        var finished: [CountdownTimer] = []
        var updated: TimerBoard = board
        for index in updated.countdowns.indices where updated.countdowns[index].finishIfDue(at: time) {
            finished.append(updated.countdowns[index])
        }
        if !finished.isEmpty {
            board = updated
            onChange?()
            for timer in finished {
                onFinish?(timer)
            }
        }
        scheduleWake()
    }

    private func updateTimer(id: String, _ change: (inout CountdownTimer) -> Void) {
        update { board in
            guard let index = board.countdowns.firstIndex(where: { (timer: CountdownTimer) -> Bool in timer.id == id }) else { return }
            change(&board.countdowns[index])
        }
    }

    private func update(_ change: (inout TimerBoard) -> Void) {
        var updated: TimerBoard = board
        change(&updated)
        guard updated != board else { return }
        board = updated
        onChange?()
        scheduleWake()
    }

    /// 一番早く終わるタイマーの時刻に1回だけ起きる。
    private func scheduleWake() {
        wakeTask?.cancel()
        let time: Date = now
        let endDates: [Date] = board.countdowns.compactMap { (timer: CountdownTimer) -> Date? in
            if case .running(let endDate) = timer.state {
                return endDate
            }
            return nil
        }
        guard let next = endDates.min() else { return }
        let seconds: Double = max(next.timeIntervalSince(time), 0) + 0.05
        wakeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}

enum TimerEditError: Error, Hashable, Sendable {
    case limitReached

    var message: String {
        "タイマーは \(TimerLimits.maximumCountdowns) 個までです。"
    }
}
