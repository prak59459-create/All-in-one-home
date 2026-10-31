import Foundation
import XCTest
@testable import MyHomeCore

/// T5-2・T5-3: メモとタスクのデータ。
final class NotesAndTasksTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func day(_ text: String) -> DayStamp {
        guard let stamp = DayStamp(text: text) else {
            preconditionFailure("テストの日付が不正: \(text)")
        }
        return stamp
    }

    // MARK: - メモ

    func testNotesAreSortedWithPinnedFirstThenRecentlyEdited() throws {
        var book: NoteBook = .initial
        try book.addNote(id: "a", now: start)
        try book.addNote(id: "b", now: start + 10)
        try book.addNote(id: "c", now: start + 20)
        book.updateNote(id: "a", title: "", body: "最初の行\n\n二行目", now: start + 30)
        book.setPinned(id: "b", true)
        XCTAssertEqual(book.sortedNotes.map(\.id), ["b", "a", "c"])
        XCTAssertEqual(book.note(id: "a")?.displayTitle, "最初の行", "タイトルが空なら本文の最初の行")
        XCTAssertEqual(book.note(id: "a")?.preview, "二行目")
        XCTAssertEqual(book.note(id: "c")?.displayTitle, "新しいメモ")
    }

    func testUnchangedEditKeepsUpdatedDate() throws {
        var book: NoteBook = .initial
        try book.addNote(id: "a", now: start)
        book.updateNote(id: "a", title: "題", body: "本文", now: start + 10)
        book.updateNote(id: "a", title: "題", body: "本文", now: start + 99)
        XCTAssertEqual(book.note(id: "a")?.updatedAt, start + 10, "変わっていなければ更新日時を進めない")
        XCTAssertEqual(book.note(id: "a")?.createdAt, start)
    }

    func testEmptyNotesAreRemovedWhenClosed() throws {
        var book: NoteBook = .initial
        try book.addNote(id: "empty", now: start)
        try book.addNote(id: "blank", now: start)
        try book.addNote(id: "kept", now: start)
        book.updateNote(id: "blank", title: " ", body: " \n\u{3000}", now: start)
        book.updateNote(id: "kept", title: "", body: "x", now: start)
        for id in ["empty", "blank", "kept"] {
            book.removeIfEmpty(id: id)
        }
        XCTAssertEqual(book.notes.map(\.id), ["kept"])
    }

    func testNoteLimits() throws {
        var book: NoteBook = .initial
        try book.addNote(id: "a", now: start)
        let longTitle: String = String(repeating: "題", count: NoteLimits.maximumTitleLength + 5)
        let longBody: String = String(repeating: "本", count: NoteLimits.maximumBodyLength + 5)
        book.updateNote(id: "a", title: longTitle, body: longBody, now: start)
        XCTAssertEqual(book.note(id: "a")?.title.count, NoteLimits.maximumTitleLength)
        XCTAssertEqual(book.note(id: "a")?.body.count, NoteLimits.maximumBodyLength)

        let full: [Note] = (0..<NoteLimits.maximumCount).map { (index: Int) -> Note in
            Note(id: "n\(index)", title: "", body: "", isPinned: false, createdAt: start, updatedAt: start)
        }
        var crowded = NoteBook(notes: full)
        XCTAssertThrowsError(try crowded.addNote(id: "extra", now: start)) { (error: Error) in
            XCTAssertEqual(error as? NoteEditError, .tooMany)
        }
        let duplicated = NoteBook(notes: [full[0], full[0]])
        XCTAssertFalse(duplicated.problems.isEmpty, "同じ ID のメモは読み込まない")
        XCTAssertTrue(crowded.problems.isEmpty)
    }

    func testSearchMatchesEveryTermIgnoringCaseAndWidth() throws {
        var book: NoteBook = .initial
        try book.addNote(id: "shopping", now: start)
        try book.addNote(id: "study", now: start + 1)
        book.updateNote(id: "shopping", title: "買い物リスト", body: "牛乳 パン", now: start + 2)
        book.updateNote(id: "study", title: "Swift メモ", body: "ＳｗｉｆｔＵＩ の勉強", now: start + 3)
        XCTAssertEqual(book.search("swiftui").map(\.id), ["study"], "全角・大文字の違いは区別しない")
        XCTAssertEqual(book.search("牛乳\u{3000}パン").map(\.id), ["shopping"], "全角の空白でも語を区切る")
        XCTAssertEqual(book.search("牛乳 Swift"), [], "すべての語を含むメモだけ")
        XCTAssertEqual(book.search("  ").map(\.id), ["study", "shopping"], "空なら全部")
    }

    // MARK: - タスク

    func testDayStampValidationTextAndOrder() throws {
        XCTAssertNil(DayStamp(year: 2026, month: 2, day: 29))
        XCTAssertNotNil(DayStamp(year: 2028, month: 2, day: 29))
        XCTAssertNil(DayStamp(text: "2026-13-01"))
        XCTAssertNil(DayStamp(text: "2026-1-01"))
        XCTAssertNil(DayStamp(text: "2026-10-29x"))
        XCTAssertEqual(day("2026-10-29").text, "2026-10-29")
        XCTAssertLessThan(day("2026-10-28"), day("2026-10-29"))
        XCTAssertLessThan(day("2025-12-31"), day("2026-01-01"))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        XCTAssertEqual(day("2026-10-31").adding(days: 1, calendar: calendar), day("2026-11-01"))
        let today: DayStamp = day("2026-12-31")
        XCTAssertEqual(today.relativeName(today: today, calendar: calendar), "今日")
        XCTAssertEqual(day("2027-01-01").relativeName(today: today, calendar: calendar), "明日", "年をまたいでも明日")
        XCTAssertEqual(day("2026-12-30").relativeName(today: today, calendar: calendar), "昨日")
        XCTAssertNil(day("2027-01-02").relativeName(today: today, calendar: calendar))
        let data: Data = try JSONEncoder().encode([day("2026-01-05")])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"["2026-01-05"]"#)
        XCTAssertThrowsError(try JSONDecoder().decode([DayStamp].self, from: Data(#"["2026-02-30"]"#.utf8)))
    }

    func testTasksAreGroupedAndSorted() throws {
        let today: DayStamp = day("2026-10-29")
        var list: TodoList = .initial
        try list.add(title: "期限切れ", due: day("2026-10-28"), priority: .none, id: "t1", now: start)
        try list.add(title: "今日・低", due: today, priority: .low, id: "t2", now: start)
        try list.add(title: "今日・高", due: today, priority: .high, id: "t3", now: start + 1)
        try list.add(title: "来週", due: day("2026-11-05"), priority: .none, id: "t4", now: start)
        try list.add(title: "明日", due: day("2026-10-30"), priority: .none, id: "t5", now: start)
        try list.add(title: "いつか", due: nil, priority: .medium, id: "t6", now: start)
        list.toggle(id: "t6", now: start + 5)
        let groups: [TodoGroup] = list.groups(today: today)
        XCTAssertEqual(groups.map(\.section), [.overdue, .today, .upcoming, .done])
        XCTAssertEqual(groups[1].items.map(\.id), ["t3", "t2"], "同じ日なら優先度の高い順")
        XCTAssertEqual(groups[2].items.map(\.id), ["t5", "t4"], "期限の近い順")
        XCTAssertEqual(list.overdueCount(today: today), 1)
        XCTAssertEqual(list.pendingCount, 5)
        XCTAssertEqual(list.groups(today: today, query: "今日").flatMap(\.items).map(\.id), ["t3", "t2"])
    }

    func testTaskEditingRules() throws {
        let today: DayStamp = day("2026-10-29")
        var list: TodoList = .initial
        XCTAssertThrowsError(try list.add(title: " \n", due: nil, priority: .none, id: "x", now: start)) { (error: Error) in
            XCTAssertEqual(error as? TodoEditError, .emptyTitle)
        }
        let long: String = String(repeating: "長", count: TodoLimits.maximumTitleLength + 10)
        try list.add(title: "  " + long, due: nil, priority: .none, id: "long", now: start)
        XCTAssertEqual(list.item(id: "long")?.title.count, TodoLimits.maximumTitleLength)

        try list.add(title: "牛乳", due: today, priority: .none, id: "milk", now: start)
        try list.add(title: "来月", due: day("2026-11-29"), priority: .none, id: "later", now: start)
        list.toggle(id: "milk", now: start + 1)
        XCTAssertEqual(list.item(id: "milk")?.completedAt, start + 1)
        list.toggle(id: "milk", now: start + 2)
        XCTAssertNil(list.item(id: "milk")?.completedAt, "未完了に戻したら完了日時を消す")

        XCTAssertThrowsError(try list.update(id: "milk", title: "", due: nil, priority: .high))
        XCTAssertEqual(list.item(id: "milk")?.title, "牛乳", "失敗した変更は反映しない")
        try list.update(id: "milk", title: "牛乳を買う", due: today, priority: .high)
        XCTAssertEqual(list.item(id: "milk")?.priority, .high)

        XCTAssertEqual(list.completeAll(dueBy: today, now: start + 3), 1, "期限が今日までのものだけ")
        XCTAssertEqual(list.item(id: "later")?.isDone, false)
        XCTAssertEqual(list.removeCompleted(), 1)
        XCTAssertNil(list.item(id: "milk"))

        let full: [TodoItem] = (0..<TodoLimits.maximumCount).map { (index: Int) -> TodoItem in
            TodoItem(id: "t\(index)", title: "t", isDone: false, due: nil, priority: .none, createdAt: start, completedAt: nil)
        }
        var crowded = TodoList(items: full)
        XCTAssertThrowsError(try crowded.add(title: "もう1つ", due: nil, priority: .none, id: "extra", now: start)) { (error: Error) in
            XCTAssertEqual(error as? TodoEditError, .tooMany)
        }
    }

    func testTodoListRoundTripsThroughArchive() throws {
        var list: TodoList = .initial
        try list.add(title: "提出", due: day("2026-12-01"), priority: .high, id: "task.a", now: start)
        list.toggle(id: "task.a", now: start + 60)
        let data: Data = try MiniAppArchiveCodec.encode(list)
        XCTAssertEqual(try MiniAppArchiveCodec.decode(TodoList.self, from: data), list)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"2026-12-01\""), "期限は日付の文字列で保存する")
    }
}
