import Foundation
import XCTest
@testable import MyHomeCore

/// Phase 8: 動きと文字の大きさの設定、ヘルプ。
final class AccessibilityPreferencesTests: XCTestCase {
    func testMotionLevelFollowsTheSettingAndTheSystem() {
        XCTAssertEqual(MotionLevel.resolve(.system, systemReduceMotion: false), .full)
        XCTAssertEqual(MotionLevel.resolve(.system, systemReduceMotion: true), .reduced, "端末の「視差効果を減らす」に従う")
        XCTAssertEqual(MotionLevel.resolve(.reduced, systemReduceMotion: false), .reduced)
        XCTAssertEqual(MotionLevel.resolve(.off, systemReduceMotion: false), MotionLevel.none)
        XCTAssertEqual(MotionLevel.resolve(.off, systemReduceMotion: true), MotionLevel.none)

        XCTAssertTrue(MotionLevel.full.allowsMovement)
        XCTAssertFalse(MotionLevel.reduced.allowsMovement, "減らす時は拡大・移動をしない")
        XCTAssertTrue(MotionLevel.reduced.allowsFade, "減らす時もフェードはする")
        XCTAssertFalse(MotionLevel.none.allowsFade)
    }

    func testOlderSettingsWithoutTheNewValuesStillLoad() throws {
        let older: Data = Data(#"{"themeID": "forest", "appearance": "dark", "showsSeconds": true}"#.utf8)
        let settings: SavedSettings = try JSONDecoder().decode(SavedSettings.self, from: older)
        XCTAssertEqual(settings.themeID, "forest")
        XCTAssertTrue(settings.showsSeconds)
        XCTAssertEqual(settings.motion, .system, "Phase 7 までの保存ファイルは端末の設定に合わせる")
        XCTAssertEqual(settings.textSize, .system)

        let broken: Data = Data(#"{"themeID": "forest", "appearance": "dark", "motion": "sideways", "textSize": 42}"#.utf8)
        let repaired: SavedSettings = try JSONDecoder().decode(SavedSettings.self, from: broken)
        XCTAssertEqual(repaired.motion, .system, "読めない値は、その値だけ初期値に戻す")
        XCTAssertEqual(repaired.textSize, .system)
        XCTAssertEqual(repaired.themeID, "forest")
    }

    func testNewSettingsRoundTrip() throws {
        let settings = SavedSettings(themeID: "mono", appearance: .light, motion: .off, textSize: .extraLarge)
        let decoded: SavedSettings = try JSONDecoder().decode(SavedSettings.self, from: try JSONEncoder().encode(settings))
        XCTAssertEqual(decoded, settings)
    }

    // Linux のテスト一覧から呼べるよう、MainActor のテストは async にする
    @MainActor
    func testChangingMotionOrTextSizeSchedulesASave() async {
        let store = SettingsStore()
        var changes: Int = 0
        store.onChange = { changes += 1 }
        store.motion = .reduced
        store.motion = .reduced
        store.textSize = .large
        XCTAssertEqual(changes, 2, "同じ値を入れ直しても保存しない")
        XCTAssertEqual(store.saved.motion, .reduced)
        XCTAssertEqual(store.saved.textSize, .large)
        XCTAssertEqual(SettingsStore(saved: store.saved).textSize, .large)
    }

    func testHelpTopicsAreUniqueAndFilled() {
        let topics: [HelpTopic] = HelpCatalog.sections().flatMap { (section: HelpSection) -> [HelpTopic] in section.topics }
        let ids: [String] = topics.map { (topic: HelpTopic) -> String in topic.id }
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertGreaterThanOrEqual(topics.count, 10)
        for topic in topics {
            XCTAssertFalse(topic.steps.isEmpty, topic.id)
            XCTAssertFalse(topic.title.isEmpty, topic.id)
        }
        XCTAssertTrue(topics.contains { (topic: HelpTopic) -> Bool in topic.steps.joined().contains("\(WidgetLimits.maximumPerPage) 個まで") })
    }

    func testHelpSearch() {
        XCTAssertEqual(HelpCatalog.search("").count, HelpCatalog.sections().count, "空なら全部")
        let folders: [String] = HelpCatalog.search("フォルダ").flatMap { (section: HelpSection) -> [String] in
            section.topics.map { (topic: HelpTopic) -> String in topic.id }
        }
        XCTAssertTrue(folders.contains("folders"))
        let ai: [String] = HelpCatalog.search("ＡＩ").flatMap { (section: HelpSection) -> [String] in
            section.topics.map { (topic: HelpTopic) -> String in topic.id }
        }
        XCTAssertTrue(ai.contains("ai"), "全角でも探せる")
        XCTAssertEqual(HelpCatalog.search("天気 上限").first?.topics.map { (topic: HelpTopic) -> String in topic.id }, ["weather-stale"], "語を全部含むものだけ")
        XCTAssertTrue(HelpCatalog.search("存在しない言葉").isEmpty)
    }
}
