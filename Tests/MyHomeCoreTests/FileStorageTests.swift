import Foundation
import XCTest
@testable import MyHomeCore

/// T2-3: ファイルへの保存（実際のファイルシステムを使う）。
final class FileStorageTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        let base: URL = FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("MyHomeTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var storage: FileHomeArchiveStorage {
        FileHomeArchiveStorage(directory: directory.appendingPathComponent("MyHome", isDirectory: true))
    }

    func testMissingFileReadsAsNil() throws {
        XCTAssertNil(try storage.read(limit: 100))
    }

    func testWriteCreatesDirectoryAndReadsBack() throws {
        let data: Data = try HomeArchiveCodec.encode(.initial())
        try storage.write(data)
        XCTAssertEqual(try storage.read(limit: HomeArchiveCodec.maximumByteCount), data)
    }

    func testWriteReplacesWholeFile() throws {
        try storage.write(Data(repeating: 0x41, count: 1000))
        try storage.write(Data("short".utf8))
        XCTAssertEqual(try storage.read(limit: 10_000), Data("short".utf8))
    }

    func testReadStopsAfterLimit() throws {
        try storage.write(Data(repeating: 0x41, count: 1000))
        XCTAssertEqual(try storage.read(limit: 10)?.count, 11, "上限を1バイト超えた所で止め、大きすぎることだけ分かればよい")
    }

    func testSetAsideKeepsFileUnderNewName() throws {
        try storage.write(Data("broken".utf8))
        let first: String = try storage.setAside(label: "unreadable")
        XCTAssertNil(try storage.read(limit: 100), "元の名前のファイルはなくなる")
        try storage.write(Data("broken again".utf8))
        let second: String = try storage.setAside(label: "unreadable")
        XCTAssertNotEqual(first, second, "同じ秒でも別の名前にする")
        let kept: Data = try Data(contentsOf: storage.directory.appendingPathComponent(first))
        XCTAssertEqual(kept, Data("broken".utf8))
        XCTAssertTrue(first.hasPrefix("home.unreadable-") && first.hasSuffix(".json"), first)
    }

    func testWriteFailureIsReported() throws {
        // 保存先に同じ名前のフォルダがあると書き込めない
        try FileManager.default.createDirectory(at: storage.fileURL, withIntermediateDirectories: true)
        XCTAssertThrowsError(try storage.write(Data("x".utf8)))
    }

    @MainActor
    func testBootstrapRestoresAfterRelaunch() async throws {
        // T2-7: 保存 → 作り直し（再起動の代わり）→ 復元
        let first: AppBootstrap = AppBootstrap.make(storage: storage, delay: .milliseconds(1))
        try first.home.add(PersistenceFixtures.link("restored", title: "復元テスト"), toPage: 0)
        first.settings.appearance = .dark
        await first.persistence.flush()

        let second: AppBootstrap = AppBootstrap.make(storage: storage)
        XCTAssertEqual(second.home.layout.item(id: "restored")?.title, "復元テスト")
        XCTAssertEqual(second.settings.appearance, .dark)
        XCTAssertNil(second.startupNotice)
    }

    @MainActor
    func testBootstrapSetsBrokenFileAside() async throws {
        try storage.write(Data("{ broken".utf8))
        let boot: AppBootstrap = AppBootstrap.make(storage: storage)
        XCTAssertEqual(boot.home.layout, DefaultLayout.make())
        let notice: String = boot.startupNotice ?? ""
        XCTAssertTrue(notice.contains("home.unreadable-"), notice)
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: storage.directory.path)
        XCTAssertEqual(names.filter { name in name.hasPrefix("home.unreadable-") }.count, 1)
        XCTAssertEqual(boot.persistence.status, .saved, "退避できたので保存は続けられる")
    }
}
