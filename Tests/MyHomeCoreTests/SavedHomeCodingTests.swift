import Foundation
import XCTest
@testable import MyHomeCore

/// T2-1: 保存形式の往復と、未知のキー・欠けた設定の扱い。
final class SavedHomeCodingTests: XCTestCase {
    func testDefaultHomeRoundTrips() throws {
        let saved = SavedHome(layout: DefaultLayout.make(), settings: SavedSettings(themeID: "forest", appearance: .dark))
        let decoded: SavedHome = try HomeArchiveCodec.decode(try HomeArchiveCodec.encode(saved))
        XCTAssertEqual(decoded, saved)
    }

    func testStressLayoutRoundTrips() throws {
        let saved = SavedHome(layout: SampleLayout.stress(itemCount: 2000, itemsPerPage: 60), settings: .defaults)
        let data: Data = try HomeArchiveCodec.encode(saved)
        XCTAssertLessThan(data.count, 1_000_000, "2,000 件でも 1MB 未満に収まる想定")
        XCTAssertEqual(try HomeArchiveCodec.decode(data), saved)
    }

    func testEncodedFormatIsStable() throws {
        let item: HomeItem = PersistenceFixtures.link("a")
        let saved = SavedHome(layout: PersistenceFixtures.layout(pages: [[item]]), settings: .defaults)
        let text: String = String(decoding: try HomeArchiveCodec.encode(saved), as: UTF8.self)
        XCTAssertTrue(text.contains("\"schemaVersion\" : \(SavedHome.currentSchemaVersion)"), text)
        XCTAssertTrue(text.contains("\"kind\" : \"url\""), text)
        XCTAssertTrue(text.contains("\"url\" : \"https://example.com/a\""), "スラッシュをエスケープしない")
        XCTAssertTrue(text.contains("\"tint\" : \"#2563EB\""), text)
    }

    func testFeatureActionRoundTrips() throws {
        let item: HomeItem = PersistenceFixtures.feature(.notes)
        let data: Data = try JSONEncoder().encode(item)
        XCTAssertEqual(try JSONDecoder().decode(HomeItem.self, from: data), item)
    }

    func testUnknownKeysAreIgnored() throws {
        let json: String = """
        {"schemaVersion": 1, "futureKey": [1, 2],
         "layout": {"pages": [{"id": "p", "extra": true, "items": [
           {"id": "a", "title": "A", "symbolName": "link", "tint": "#2563EB", "note": "x",
            "action": {"kind": "url", "url": "https://example.com", "openIn": "browser"}}]}], "dock": []},
         "settings": {"themeID": "mono", "appearance": "light", "fontScale": 2}}
        """
        let saved: SavedHome = try HomeArchiveCodec.decode(PersistenceFixtures.json(json))
        XCTAssertEqual(saved.layout.pages[0].items[0].id, "a")
        XCTAssertEqual(saved.settings, SavedSettings(themeID: "mono", appearance: .light))
    }

    func testMissingOrBrokenSettingsFallBackToDefaults() throws {
        let noSettings: String = #"{"schemaVersion": 1, "layout": {"pages": [], "dock": []}}"#
        XCTAssertEqual(try HomeArchiveCodec.decode(PersistenceFixtures.json(noSettings)).settings, .defaults)

        let broken: String = #"{"schemaVersion": 1, "layout": {"pages": [], "dock": []}, "settings": {"themeID": 3, "appearance": "sepia"}}"#
        XCTAssertEqual(try HomeArchiveCodec.decode(PersistenceFixtures.json(broken)).settings, .defaults)
    }

    func testUnknownThemeIsKeptButResolvesToFallback() async throws {
        let json: String = #"{"schemaVersion": 1, "layout": {"pages": [], "dock": []}, "settings": {"themeID": "aurora"}}"#
        let saved: SavedHome = try HomeArchiveCodec.decode(PersistenceFixtures.json(json))
        XCTAssertEqual(saved.settings.themeID, "aurora")
        let store: SettingsStore = await SettingsStore(saved: saved.settings)
        let resolved: String = await store.theme.id
        XCTAssertEqual(resolved, ThemeCatalog.defaultID)
    }

    private func fixture(_ name: String) throws -> Data {
        let root: URL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(contentsOf: root.appendingPathComponent("scripts/fixtures/\(name)"))
    }

    func testSimulatorRestoreFixtureDecodes() throws {
        // scripts/smoke-test-simulator.sh の restore で使う保存ファイル（版 1）が、今の形式へ移行して読めることを確かめる
        let saved: SavedHome = try HomeArchiveCodec.decode(try fixture("home-restore.json"))
        XCTAssertEqual(saved.layout.pages[0].items.map(\.title), ["復元テスト1", "復元テスト2", "AI"])
        XCTAssertEqual(saved.settings, SavedSettings(themeID: "forest", appearance: .dark))
    }

    func testSimulatorFolderFixtureDecodes() throws {
        // editing / folder で使う保存ファイル（版 2、フォルダ入り）。-MyHomeOpenFolder folder.check で開くフォルダがあること
        let saved: SavedHome = try HomeArchiveCodec.decode(try fixture("home-folder.json"))
        XCTAssertEqual(saved.layout.item(id: "folder.check")?.folderItems?.count, 3)
        XCTAssertEqual(saved.layout.pages.count, 2)
    }

    func testDecodedLayoutIsNormalized() throws {
        let json: String = #"{"schemaVersion": 1, "layout": {"pages": [], "dock": []}}"#
        let saved: SavedHome = try HomeArchiveCodec.decode(PersistenceFixtures.json(json))
        XCTAssertEqual(saved.layout.pages.count, 1, "ページが1枚もなければ空のページを作る")
    }
}
