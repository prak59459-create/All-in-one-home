/// 読み込んだタイマーを使える範囲に整える。タイマーは失っても困らないので、拒否せずに直す。
enum TimerValidator {
    static func sanitized(_ board: TimerBoard) -> TimerBoard {
        TimerBoard(countdowns: sanitizedCountdowns(board.countdowns), stopwatch: sanitizedStopwatch(board.stopwatch))
    }

    /// 数の上限、空の ID・長すぎる ID・重複した ID、長すぎる名前を直す。
    private static func sanitizedCountdowns(_ timers: [CountdownTimer]) -> [CountdownTimer] {
        var seen: Set<String> = []
        var countdowns: [CountdownTimer] = []
        for timer in timers.prefix(TimerLimits.maximumCountdowns) {
            guard !timer.id.isEmpty, timer.id.count <= LayoutLimits.maximumIDLength, seen.insert(timer.id).inserted else { continue }
            let label: String = String(timer.label.prefix(TimerLimits.maximumLabelLength))
            countdowns.append(CountdownTimer(id: timer.id, label: label, duration: timer.duration, state: timer.state))
        }
        return countdowns
    }

    /// ラップの数の上限と、壊れた計測時間を直す。
    private static func sanitizedStopwatch(_ original: Stopwatch) -> Stopwatch {
        var stopwatch: Stopwatch = original
        if stopwatch.laps.count > TimerLimits.maximumLaps {
            stopwatch.laps = Array(stopwatch.laps.prefix(TimerLimits.maximumLaps))
        }
        if !stopwatch.accumulated.isFinite || stopwatch.accumulated < 0 {
            stopwatch = Stopwatch()
        }
        return stopwatch
    }
}
