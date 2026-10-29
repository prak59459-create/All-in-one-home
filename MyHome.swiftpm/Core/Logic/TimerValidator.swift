/// 読み込んだタイマーを使える範囲に整える。タイマーは失っても困らないので、拒否せずに直す。
enum TimerValidator {
    static func sanitized(_ board: TimerBoard) -> TimerBoard {
        var seen: Set<String> = []
        var countdowns: [CountdownTimer] = []
        for timer in board.countdowns.prefix(TimerLimits.maximumCountdowns) {
            guard !timer.id.isEmpty, timer.id.count <= LayoutLimits.maximumIDLength, seen.insert(timer.id).inserted else { continue }
            let label: String = String(timer.label.prefix(TimerLimits.maximumLabelLength))
            countdowns.append(CountdownTimer(id: timer.id, label: label, duration: timer.duration, state: timer.state))
        }
        var stopwatch: Stopwatch = board.stopwatch
        if stopwatch.laps.count > TimerLimits.maximumLaps {
            stopwatch.laps = Array(stopwatch.laps.prefix(TimerLimits.maximumLaps))
        }
        if !stopwatch.accumulated.isFinite || stopwatch.accumulated < 0 {
            stopwatch = Stopwatch()
        }
        return TimerBoard(countdowns: countdowns, stopwatch: stopwatch)
    }
}
