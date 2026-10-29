import Foundation

/// カウントダウンタイマー（F0218–F0224、F0227）。時刻は引数で受け取り、単体テストで時間を進められるようにする。
/// 実行中は終了時刻だけを持つので、アプリが裏に回っていても戻った時に正しい残り時間を表示できる
/// （裏に回っている間は音を鳴らせない。F0237）。
struct CountdownTimer: Identifiable, Hashable, Codable, Sendable {
    enum State: Hashable, Codable, Sendable {
        case idle
        case running(endDate: Date)
        case paused(remaining: TimeInterval)
        case finished
    }

    let id: String
    var label: String
    var duration: TimeInterval
    var state: State

    init(id: String, label: String, duration: TimeInterval, state: State = .idle) {
        self.id = id
        self.label = label
        self.duration = TimerLimits.clampedDuration(duration)
        self.state = state
    }

    func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .idle:
            return duration
        case .running(let endDate):
            return max(endDate.timeIntervalSince(now), 0)
        case .paused(let remaining):
            return remaining
        case .finished:
            return 0
        }
    }

    var isRunning: Bool {
        if case .running = state {
            return true
        }
        return false
    }

    /// 開始・再開する。終わっていれば最初から。
    mutating func start(at now: Date) {
        let left: TimeInterval = remaining(at: now)
        let seconds: TimeInterval = left > 0 ? left : duration
        state = .running(endDate: now.addingTimeInterval(seconds))
    }

    mutating func pause(at now: Date) {
        guard case .running = state else { return }
        state = .paused(remaining: remaining(at: now))
    }

    mutating func reset() {
        state = .idle
    }

    /// 終了時刻を過ぎていれば「終了」にする。終了にした時は true。
    mutating func finishIfDue(at now: Date) -> Bool {
        guard case .running(let endDate) = state, endDate <= now else { return false }
        state = .finished
        return true
    }
}

/// ストップウォッチ（F0225、F0226）。
struct Stopwatch: Hashable, Codable, Sendable {
    var accumulated: TimeInterval = 0
    /// 計測中なら開始した時刻。
    var startedAt: Date?
    /// ラップを押した時の経過時間。
    var laps: [TimeInterval] = []

    var isRunning: Bool {
        startedAt != nil
    }

    func elapsed(at now: Date) -> TimeInterval {
        guard let startedAt else { return accumulated }
        return accumulated + max(now.timeIntervalSince(startedAt), 0)
    }

    mutating func start(at now: Date) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    mutating func pause(at now: Date) {
        guard startedAt != nil else { return }
        accumulated = elapsed(at: now)
        startedAt = nil
    }

    mutating func reset() {
        self = Stopwatch()
    }

    mutating func lap(at now: Date) {
        guard isRunning, laps.count < TimerLimits.maximumLaps else { return }
        laps.append(elapsed(at: now))
    }
}

/// タイマーの一式（保存する単位）。
struct TimerBoard: Hashable, Codable, Sendable {
    var countdowns: [CountdownTimer]
    var stopwatch: Stopwatch

    static func initial() -> TimerBoard {
        let presets: [CountdownTimer] = [
            CountdownTimer(id: "timer.3min", label: "3分", duration: 180),
            CountdownTimer(id: "timer.25min", label: "集中 25分", duration: 1500)
        ]
        return TimerBoard(countdowns: presets, stopwatch: Stopwatch())
    }
}

enum TimerLimits {
    static let maximumCountdowns: Int = 20
    static let maximumLaps: Int = 100
    static let maximumLabelLength: Int = 30
    static let minimumDuration: TimeInterval = 1
    static let maximumDuration: TimeInterval = 24 * 60 * 60

    static func clampedDuration(_ seconds: TimeInterval) -> TimeInterval {
        guard seconds.isFinite else { return minimumDuration }
        return min(max(seconds.rounded(), minimumDuration), maximumDuration)
    }
}

/// 残り時間・経過時間の表示（例: 3:05、1:02:03、0:12.3）。
enum TimeText {
    static func clock(_ seconds: TimeInterval) -> String {
        let total: Int = Int(max(seconds, 0).rounded(.up))
        let hours: Int = total / 3600
        let minutes: Int = (total % 3600) / 60
        let secs: Int = total % 60
        if hours > 0 {
            return "\(hours):\(twoDigits(minutes)):\(twoDigits(secs))"
        }
        return "\(minutes):\(twoDigits(secs))"
    }

    /// ストップウォッチ用（0.1 秒まで。切り捨て）。
    static func stopwatch(_ seconds: TimeInterval) -> String {
        let tenths: Int = Int((max(seconds, 0) * 10).rounded(.down))
        let total: Int = tenths / 10
        let minutes: Int = total / 60
        let secs: Int = total % 60
        return "\(minutes):\(twoDigits(secs)).\(tenths % 10)"
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
