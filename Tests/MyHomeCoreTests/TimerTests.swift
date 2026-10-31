import Foundation
import XCTest
@testable import MyHomeCore

/// T4-4: カウントダウン・ストップウォッチ（時刻を与えて進める）と、タイマーの保存・終了の通知。
final class TimerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testCountdownRunsPausesAndResumes() {
        var timer = CountdownTimer(id: "t", label: "3分", duration: 180)
        XCTAssertEqual(timer.remaining(at: start), 180)
        timer.start(at: start)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(60)), 120)
        timer.pause(at: start.addingTimeInterval(60))
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(500)), 120, "止めている間は減らない")
        timer.start(at: start.addingTimeInterval(500))
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(560)), 60)
        XCTAssertFalse(timer.finishIfDue(at: start.addingTimeInterval(600)))
        XCTAssertTrue(timer.finishIfDue(at: start.addingTimeInterval(620)))
        XCTAssertEqual(timer.state, .finished)
        timer.start(at: start.addingTimeInterval(700))
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(700)), 180, "終わった後は最初から")
        timer.reset()
        XCTAssertEqual(timer.state, .idle)
    }

    func testDurationIsClamped() {
        XCTAssertEqual(CountdownTimer(id: "a", label: "", duration: 0).duration, TimerLimits.minimumDuration)
        XCTAssertEqual(CountdownTimer(id: "b", label: "", duration: 1e9).duration, TimerLimits.maximumDuration)
        XCTAssertEqual(CountdownTimer(id: "c", label: "", duration: .nan).duration, TimerLimits.minimumDuration)
    }

    func testStopwatchAccumulatesAndRecordsLaps() {
        var watch = Stopwatch()
        watch.start(at: start)
        watch.lap(at: start.addingTimeInterval(10))
        watch.pause(at: start.addingTimeInterval(12.5))
        XCTAssertEqual(watch.elapsed(at: start.addingTimeInterval(100)), 12.5)
        watch.lap(at: start.addingTimeInterval(100))
        XCTAssertEqual(watch.laps, [10], "止めている間はラップを記録しない")
        watch.start(at: start.addingTimeInterval(200))
        XCTAssertEqual(watch.elapsed(at: start.addingTimeInterval(202.5)), 15)
        watch.reset()
        XCTAssertEqual(watch, Stopwatch())
    }

    func testTimeTextFormatting() {
        XCTAssertEqual(TimeText.clock(185), "3:05")
        XCTAssertEqual(TimeText.clock(3723), "1:02:03")
        XCTAssertEqual(TimeText.clock(0.2), "0:01", "残りがある間は切り上げて 0 秒と表示しない")
        XCTAssertEqual(TimeText.stopwatch(72.34), "1:12.3")
    }

    func testTimerBoardIsSanitizedOnLoad() {
        let duplicate = CountdownTimer(id: "same", label: String(repeating: "長", count: 50), duration: 60)
        var board = TimerBoard(countdowns: [duplicate, duplicate, CountdownTimer(id: "", label: "", duration: 60)], stopwatch: Stopwatch())
        board.stopwatch.accumulated = -5
        let clean: TimerBoard = TimerValidator.sanitized(board)
        XCTAssertEqual(clean.countdowns.map(\.id), ["same"])
        XCTAssertEqual(clean.countdowns[0].label.count, TimerLimits.maximumLabelLength)
        XCTAssertEqual(clean.stopwatch, Stopwatch())
    }

    @MainActor
    func testStoreFinishesTimerAndReportsIt() async throws {
        let clock = TestClock(start)
        let store = TimerStore(board: TimerBoard(countdowns: [CountdownTimer(id: "t", label: "短い", duration: 60)], stopwatch: Stopwatch()),
                               clock: { clock.now })
        var finished: [String] = []
        var changes: Int = 0
        store.onFinish = { timer in finished.append(timer.label) }
        store.onChange = { changes += 1 }
        store.start(id: "t")
        XCTAssertTrue(store.board.countdowns[0].isRunning)
        clock.advance(by: 30)
        store.refresh()
        XCTAssertTrue(finished.isEmpty)
        clock.advance(by: 31)
        store.refresh()
        XCTAssertEqual(finished, ["短い"])
        XCTAssertEqual(store.board.countdowns[0].state, .finished)
        XCTAssertEqual(changes, 2, "開始と終了の2回だけ保存を予約する（毎秒は保存しない）")
    }

    @MainActor
    func testStoreAddsAndRemovesCountdowns() async throws {
        let store = TimerStore(board: TimerBoard(countdowns: [], stopwatch: Stopwatch()))
        try store.addCountdown(label: "  ", duration: 90)
        XCTAssertEqual(store.board.countdowns[0].label, "1:30", "名前がなければ時間を名前にする")
        let id: String = store.board.countdowns[0].id
        store.removeCountdown(id: id)
        XCTAssertTrue(store.board.countdowns.isEmpty)
        for index in 0..<TimerLimits.maximumCountdowns {
            try store.addCountdown(label: "t\(index)", duration: 60)
        }
        XCTAssertThrowsError(try store.addCountdown(label: "over", duration: 60))
    }

    @MainActor
    func testTimersAreSavedWithTheHome() async throws {
        let storage = MemoryArchiveStorage()
        let boot: AppBootstrap = AppBootstrap.make(storage: storage, delay: .milliseconds(1))
        boot.timers.startStopwatch()
        await boot.persistence.flush()
        let saved: SavedHome = try HomeArchiveCodec.decode(try XCTUnwrap(storage.data))
        XCTAssertTrue(saved.timers.stopwatch.isRunning)
        let again: AppBootstrap = AppBootstrap.make(storage: storage)
        XCTAssertTrue(again.timers.board.stopwatch.isRunning, "再起動後も計測中のまま")
    }
}

/// テスト用の時計。
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) {
        current = start
    }

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(by seconds: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }
}
