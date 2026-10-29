import Foundation
import XCTest
@testable import MyHomeCore

/// T2-2: 壊れた JSON・新しい版・構造の問題を拒否する（F0821、F0824、F0940）。
final class HomeArchiveCodecTests: XCTestCase {
    private func decodeError(_ text: String) -> HomeArchiveError? {
        decodeError(PersistenceFixtures.json(text))
    }

    private func decodeError(_ data: Data) -> HomeArchiveError? {
        do {
            _ = try HomeArchiveCodec.decode(data)
            return nil
        } catch {
            return error as? HomeArchiveError
        }
    }

    private func isMalformed(_ error: HomeArchiveError?) -> Bool {
        if case .malformed = error {
            return true
        }
        return false
    }

    func testBrokenJSONIsRejected() throws {
        let valid: String = String(decoding: try HomeArchiveCodec.encode(.initial()), as: UTF8.self)
        let samples: [String] = ["", " ", "{", "[]", "null", "\"home\"", "{\"schemaVersion\": 1", String(valid.prefix(valid.count / 2))]
        for sample in samples {
            XCTAssertTrue(isMalformed(decodeError(sample)), "拒否されない: \(sample.prefix(40))")
        }
    }

    func testBinaryGarbageIsRejected() {
        let garbage = Data([0xFF, 0xFE, 0x00, 0x7B, 0x22, 0x80])
        XCTAssertTrue(isMalformed(decodeError(garbage)))
    }

    func testMissingOrWrongVersionIsRejected() {
        XCTAssertTrue(isMalformed(decodeError(#"{"layout": {"pages": [], "dock": []}}"#)))
        XCTAssertTrue(isMalformed(decodeError(#"{"schemaVersion": "1", "layout": {"pages": [], "dock": []}}"#)))
        XCTAssertTrue(isMalformed(decodeError(#"{"schemaVersion": 0, "layout": {"pages": [], "dock": []}}"#)))
        XCTAssertTrue(isMalformed(decodeError(#"{"schemaVersion": -1, "layout": {"pages": [], "dock": []}}"#)))
    }

    func testNewerVersionIsRejectedWithoutGuessing() {
        let newer: Int = SavedHome.currentSchemaVersion + 1
        let error: HomeArchiveError? = decodeError("{\"schemaVersion\": \(newer), \"layout\": {\"whatever\": true}}")
        XCTAssertEqual(error, .newerVersion(newer))
    }

    func testWrongTypesAreRejected() {
        let wrongTint: String = """
        {"schemaVersion": 1, "layout": {"pages": [{"id": "p", "items": [
          {"id": "a", "title": "A", "symbolName": "link", "tint": "blue", "action": {"kind": "url", "url": "https://example.com"}}]}], "dock": []}}
        """
        let unknownAction: String = """
        {"schemaVersion": 1, "layout": {"pages": [{"id": "p", "items": [
          {"id": "a", "title": "A", "symbolName": "link", "tint": "#2563EB", "action": {"kind": "script", "code": "x"}}]}], "dock": []}}
        """
        let unknownFeature: String = """
        {"schemaVersion": 1, "layout": {"pages": [{"id": "p", "items": [
          {"id": "a", "title": "A", "symbolName": "link", "tint": "#2563EB", "action": {"kind": "feature", "feature": "camera"}}]}], "dock": []}}
        """
        XCTAssertTrue(isMalformed(decodeError(wrongTint)))
        XCTAssertTrue(isMalformed(decodeError(unknownAction)))
        XCTAssertTrue(isMalformed(decodeError(unknownFeature)))
    }

    func testMalformedMessageNamesTheKey() {
        guard case .malformed(let detail) = decodeError(#"{"schemaVersion": 1}"#) else {
            return XCTFail("malformed になるはず")
        }
        XCTAssertTrue(detail.contains("layout"), detail)
    }

    func testTooLargeDataIsRejectedBeforeParsing() {
        let data = Data(count: HomeArchiveCodec.maximumByteCount + 1)
        XCTAssertEqual(decodeError(data), .tooLarge(byteCount: HomeArchiveCodec.maximumByteCount + 1))
    }

    func testDuplicateItemIDsAreRejected() throws {
        let layout: HomeLayout = PersistenceFixtures.layout(pages: [[PersistenceFixtures.link("a")]], dock: [PersistenceFixtures.link("a")])
        let data: Data = try PersistenceFixtures.encoded(SavedHome(layout: layout, settings: .defaults))
        XCTAssertEqual(decodeError(data), .invalid([.duplicateItemID("a")]))
    }

    func testDuplicatePageIDsAreRejected() throws {
        let pages: [HomePage] = [HomePage(id: "p", items: []), HomePage(id: "p", items: [])]
        let data: Data = try PersistenceFixtures.encoded(SavedHome(layout: HomeLayout(pages: pages, dock: []), settings: .defaults))
        XCTAssertEqual(decodeError(data), .invalid([.duplicatePageID("p")]))
    }

    func testEmptyIDAndLongTextAreRejected() throws {
        let longTitle: String = String(repeating: "あ", count: LayoutLimits.maximumTitleLength + 1)
        let items: [HomeItem] = [PersistenceFixtures.link(""), PersistenceFixtures.link("b", title: longTitle)]
        let data: Data = try PersistenceFixtures.encoded(SavedHome(layout: PersistenceFixtures.layout(pages: [items]), settings: .defaults))
        XCTAssertEqual(decodeError(data), .invalid([.invalidItemID(""), .textTooLong(itemID: "b")]))
    }

    func testTooManyItemsAreRejected() throws {
        var items: [HomeItem] = []
        for index in 0...LayoutLimits.maximumItems {
            items.append(PersistenceFixtures.link("i\(index)"))
        }
        let data: Data = try PersistenceFixtures.encoded(SavedHome(layout: PersistenceFixtures.layout(pages: [items]), settings: .defaults))
        XCTAssertEqual(decodeError(data), .invalid([.tooManyItems(LayoutLimits.maximumItems + 1)]))
    }

    func testReportedProblemsAreCapped() throws {
        var items: [HomeItem] = []
        for _ in 0..<30 {
            items.append(PersistenceFixtures.link("same"))
        }
        let data: Data = try PersistenceFixtures.encoded(SavedHome(layout: PersistenceFixtures.layout(pages: [items]), settings: .defaults))
        guard case .invalid(let problems) = decodeError(data) else {
            return XCTFail("invalid になるはず")
        }
        XCTAssertEqual(problems.count, LayoutValidator.maximumReportedProblems)
    }

    func testDisallowedURLIsKeptAndRejectedWhenOpened() throws {
        // URL の判定は開く時に行う（保存済みの配置全体を読めなくしない）
        let item = HomeItem(id: "js", title: "JS", symbolName: "link", tint: RGBAColor(hex: 0x111111), action: .openURL("javascript:alert(1)"))
        let data: Data = try PersistenceFixtures.encoded(SavedHome(layout: PersistenceFixtures.layout(pages: [[item]]), settings: .defaults))
        let saved: SavedHome = try HomeArchiveCodec.decode(data)
        guard case .rejectURL = LaunchPlanner.plan(for: saved.layout.pages[0].items[0].action) else {
            return XCTFail("開く時に拒否されるはず")
        }
    }

    func testMessagesAreReadable() {
        XCTAssertTrue(HomeArchiveError.newerVersion(3).message.contains("新しい版"))
        XCTAssertTrue(HomeArchiveError.invalid([.duplicateItemID("a")]).message.contains("重複"))
        XCTAssertTrue(LayoutProblem.invalidItemID(String(repeating: "x", count: 300)).message.count < 80, "長い ID は省略する")
    }
}
