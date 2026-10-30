import Foundation
import XCTest
@testable import MyHomeCore

/// T5-1: ミニアプリの保存（1アプリ1ファイル、開いた時だけ読む、読めないファイルの退避、保存の間引き）。
final class MiniAppStorageTests: XCTestCase {
    /// 上限を小さくした、テスト用のミニアプリのデータ。
    private struct TinyContent: MiniAppContent {
        static let fileID: String = "tiny"
        static let formatVersion: Int = 1
        static let maximumByteCount: Int = 200
        static let initial: TinyContent = TinyContent(value: "")

        var value: String

        var problems: [String] {
            value == "bad" ? ["不正な値です。"] : []
        }
    }

    @MainActor
    private func waitUntilSettled<Content: MiniAppContent>(_ document: MiniAppDocument<Content>, timeout: TimeInterval = 5) async {
        let deadline: Date = Date().addingTimeInterval(timeout)
        while document.status == .pending && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func encoded(_ value: String) throws -> Data {
        try MiniAppArchiveCodec.encode(TinyContent(value: value))
    }

    func testCodecRoundTripsAndNamesTheApp() throws {
        var book: NoteBook = .initial
        try book.addNote(id: "note.a", now: Date(timeIntervalSince1970: 100))
        book.updateNote(id: "note.a", title: "買い物", body: "牛乳\nパン", now: Date(timeIntervalSince1970: 200))
        let data: Data = try MiniAppArchiveCodec.encode(book)
        XCTAssertEqual(try MiniAppArchiveCodec.decode(NoteBook.self, from: data), book)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"app\" : \"notes\""))
        XCTAssertThrowsError(try MiniAppArchiveCodec.decode(TodoList.self, from: data)) { (error: Error) in
            XCTAssertEqual(error as? MiniAppArchiveError, .wrongApp("notes"), "別のミニアプリのファイルは読まない")
        }
    }

    func testNewerBrokenAndInvalidFilesAreRejected() throws {
        let newer = Data(#"{"schemaVersion": 2, "app": "tiny", "content": {"value": "x"}}"#.utf8)
        XCTAssertThrowsError(try MiniAppArchiveCodec.decode(TinyContent.self, from: newer)) { (error: Error) in
            XCTAssertEqual(error as? MiniAppArchiveError, .newerVersion(2))
        }
        XCTAssertThrowsError(try MiniAppArchiveCodec.decode(TinyContent.self, from: Data("{".utf8))) { (error: Error) in
            guard case .malformed? = error as? MiniAppArchiveError else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try MiniAppArchiveCodec.decode(TinyContent.self, from: try encoded("bad"))) { (error: Error) in
            XCTAssertEqual(error as? MiniAppArchiveError, .invalid(["不正な値です。"]))
        }
        let tooLarge = Data(count: TinyContent.maximumByteCount + 1)
        XCTAssertThrowsError(try MiniAppArchiveCodec.decode(TinyContent.self, from: tooLarge)) { (error: Error) in
            XCTAssertEqual(error as? MiniAppArchiveError, .tooLarge(byteCount: TinyContent.maximumByteCount + 1))
        }
        XCTAssertThrowsError(try MiniAppArchiveCodec.encode(TinyContent(value: String(repeating: "x", count: 300))))
    }

    @MainActor
    func testDocumentLoadsOnceAndCoalescesSaves() async throws {
        let storage = MemoryArchiveStorage(data: try encoded("保存済み"))
        let document = MiniAppDocument<TinyContent>(storage: storage, delay: .milliseconds(20))
        document.update { (content: inout TinyContent) in content.value = "読む前の変更" }
        XCTAssertEqual(document.content, .initial, "読み込みの前の変更は受け付けない（読み込んだ内容で消えるため）")
        await document.load()
        await document.load()
        XCTAssertTrue(document.isLoaded)
        XCTAssertEqual(document.content.value, "保存済み")
        XCTAssertEqual(storage.writeCount, 0, "読むだけでは書かない")

        document.update { (content: inout TinyContent) in content.value = "a" }
        document.update { (content: inout TinyContent) in content.value = "ab" }
        XCTAssertEqual(document.status, .pending)
        await waitUntilSettled(document)
        XCTAssertEqual(document.status, .saved)
        XCTAssertEqual(storage.writeCount, 1, "続けて変えた分は1回にまとめる")
        XCTAssertEqual(try MiniAppArchiveCodec.decode(TinyContent.self, from: try XCTUnwrap(storage.data)).value, "ab")

        document.update { (content: inout TinyContent) in content.value = "ab" }
        await document.flush()
        XCTAssertEqual(storage.writeCount, 1, "同じ値なら書かない")
    }

    @MainActor
    func testFlushWritesImmediately() async {
        let storage = MemoryArchiveStorage()
        let document = MiniAppDocument<TinyContent>(storage: storage, delay: .seconds(60))
        await document.load()
        document.update { (content: inout TinyContent) in content.value = "すぐ保存" }
        await document.flush()
        XCTAssertEqual(storage.writeCount, 1)
        XCTAssertEqual(document.status, .saved)
    }

    @MainActor
    func testUnreadableFileIsSetAsideAndExplained() async throws {
        let storage = MemoryArchiveStorage(data: Data("壊れたデータ".utf8))
        let document = MiniAppDocument<TinyContent>(storage: storage, delay: .milliseconds(1))
        await document.load()
        XCTAssertEqual(document.content, .initial)
        XCTAssertEqual(storage.setAsideNames.count, 1, "読めなかったファイルは消さずに別名で残す")
        let notice: String = try XCTUnwrap(document.notice)
        XCTAssertTrue(notice.contains("読み込めなかった"), notice)
        XCTAssertTrue(notice.contains(storage.setAsideNames[0]), notice)
        document.update { (content: inout TinyContent) in content.value = "新しい内容" }
        await document.flush()
        XCTAssertEqual(storage.writeCount, 1, "退避できたので、新しい内容は保存できる")
    }

    @MainActor
    func testSetAsideFailureStopsSaving() async {
        let broken = Data("壊れたデータ".utf8)
        let storage = MemoryArchiveStorage(data: broken)
        storage.failSetAside(true)
        let document = MiniAppDocument<TinyContent>(storage: storage, delay: .milliseconds(1))
        await document.load()
        guard case .disabled = document.status else {
            return XCTFail("保存を止めるはず: \(document.status)")
        }
        document.update { (content: inout TinyContent) in content.value = "新しい内容" }
        await document.flush()
        XCTAssertEqual(storage.writeCount, 0)
        XCTAssertEqual(storage.data, broken, "退避できなかったファイルを上書きしない")
    }

    @MainActor
    func testWriteFailuresAreReported() async {
        let storage = MemoryArchiveStorage()
        let document = MiniAppDocument<TinyContent>(storage: storage, delay: .milliseconds(1))
        await document.load()
        document.update { (content: inout TinyContent) in content.value = String(repeating: "x", count: 300) }
        await document.flush()
        guard case .failed(let message) = document.status else {
            return XCTFail("大きすぎる内容は保存できないことを表示するはず: \(document.status)")
        }
        XCTAssertTrue(message.contains("大きすぎます"), message)

        storage.failWrites(true)
        document.update { (content: inout TinyContent) in content.value = "短い" }
        await document.flush()
        guard case .failed = document.status else {
            return XCTFail("書き込みの失敗を表示するはず: \(document.status)")
        }
        storage.failWrites(false)
        await document.flush()
        XCTAssertEqual(document.status, .saved, "やり直しで保存できる")
    }

    @MainActor
    func testDisabledDocumentNeverWrites() async {
        let document = MiniAppDocument<TinyContent>(storage: nil, disabledReason: "検証用")
        await document.load()
        XCTAssertTrue(document.isLoaded)
        document.update { (content: inout TinyContent) in content.value = "画面の中だけ" }
        XCTAssertEqual(document.content.value, "画面の中だけ", "保存しない時も、開いている間は使える")
        await document.flush()
        XCTAssertEqual(document.status, .disabled("検証用"))
    }

    @MainActor
    func testLibraryKeepsOneDocumentPerAppAndFlushesAll() async throws {
        var storages: [String: MemoryArchiveStorage] = [:]
        let library = MiniAppLibrary(
            makeStorage: { (fileID: String) -> (any HomeArchiveStorage)? in
                let storage = MemoryArchiveStorage()
                storages[fileID] = storage
                return storage
            },
            delay: .seconds(60)
        )
        let notes: MiniAppDocument<NoteBook> = library.document(NoteBook.self)
        XCTAssertTrue(notes === library.document(NoteBook.self), "同じミニアプリには同じデータを渡す")
        let tasks: MiniAppDocument<TodoList> = library.document(TodoList.self)
        XCTAssertEqual(Set(storages.keys), ["notes", "tasks"], "開いたミニアプリの分だけ作る")
        await notes.load()
        await tasks.load()
        try notes.perform { (book: inout NoteBook) in try book.addNote(id: "note.a", now: Date()) }
        try tasks.perform { (list: inout TodoList) in try list.add(title: "牛乳", due: nil, priority: .none, id: "task.a", now: Date()) }
        await library.flushAll()
        XCTAssertEqual(storages["notes"]?.writeCount, 1)
        XCTAssertEqual(storages["tasks"]?.writeCount, 1)
    }

    private func fixture(_ name: String) throws -> Data {
        let root: URL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(contentsOf: root.appendingPathComponent("scripts/fixtures/apps/\(name)"))
    }

    func testSimulatorFixturesDecode() throws {
        // scripts/smoke-test-simulator.sh の app-* で置く保存ファイルが、今の形式で読めることを確かめる
        let book: NoteBook = try MiniAppArchiveCodec.decode(NoteBook.self, from: try fixture("notes.json"))
        XCTAssertEqual(book.sortedNotes.map(\.displayTitle), ["買い物（確認用）", "Phase 5 のミニアプリを Simulator で確認する。"])
        let list: TodoList = try MiniAppArchiveCodec.decode(TodoList.self, from: try fixture("tasks.json"))
        let today: DayStamp = try XCTUnwrap(DayStamp(text: "2026-10-29"))
        XCTAssertEqual(list.groups(today: today).map(\.section), [.overdue, .upcoming, .someday, .done])
        let calculator: CalculatorState = try MiniAppArchiveCodec.decode(CalculatorState.self, from: try fixture("calculator.json"))
        XCTAssertEqual(calculator.mainText, "12 + (3.5 × 2)")
        XCTAssertEqual(calculator.previewText, "19")
        let converter: ConverterState = try MiniAppArchiveCodec.decode(ConverterState.self, from: try fixture("converter.json"))
        XCTAssertEqual(converter.results().first { (result: ConversionResult) -> Bool in result.unit.id == "temperature.f" }?.text, "212")
        let text: TextToolsState = try MiniAppArchiveCodec.decode(TextToolsState.self, from: try fixture("texttools.json"))
        XCTAssertTrue(text.text.hasPrefix("{\"name\":\"MyHome\""))
    }

    func testFileStorageUsesOneFilePerApp() throws {
        let base: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("miniapps-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let apps: URL = base.appendingPathComponent("Apps", isDirectory: true)
        let storage = FileHomeArchiveStorage(directory: apps, baseName: "notes")
        try storage.write(Data("{}".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: apps.appendingPathComponent("notes.json").path))
        let name: String = try storage.setAside(label: "unreadable")
        XCTAssertTrue(name.hasPrefix("notes.unreadable-"), name)
        XCTAssertTrue(FileManager.default.fileExists(atPath: apps.appendingPathComponent(name).path))
        XCTAssertNil(try storage.read(limit: 100))
    }
}
