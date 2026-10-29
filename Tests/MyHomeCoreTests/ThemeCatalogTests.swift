import XCTest
@testable import MyHomeCore

final class ThemeCatalogTests: XCTestCase {
    func testPresetIDsAreUnique() {
        let ids: [String] = ThemeCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testDefaultIDExists() {
        XCTAssertTrue(ThemeCatalog.all.contains { $0.id == ThemeCatalog.defaultID })
    }

    func testUnknownIDFallsBackToDefault() {
        XCTAssertEqual(ThemeCatalog.preset(id: "removed-theme").id, ThemeCatalog.defaultID)
    }

    /// 時計とアイコン名は壁紙の上に直接置くため、壁紙の両端に対して文字のコントラスト基準（4.5:1）を満たすこと。
    func testLabelContrastMeetsTextGuideline() {
        for preset in ThemeCatalog.all {
            for palette in [preset.light, preset.dark] {
                let top: Double = palette.label.contrastRatio(with: palette.wallpaperTop)
                let bottom: Double = palette.label.contrastRatio(with: palette.wallpaperBottom)
                XCTAssertGreaterThanOrEqual(min(top, bottom), 4.5, "\(preset.id)")
            }
        }
    }

    /// 強調色はページインジケーターなどの部品に使うため、非テキストの基準（3:1）を満たすこと。
    func testAccentContrastMeetsComponentGuideline() {
        for preset in ThemeCatalog.all {
            for palette in [preset.light, preset.dark] {
                let top: Double = palette.accent.contrastRatio(with: palette.wallpaperTop)
                let bottom: Double = palette.accent.contrastRatio(with: palette.wallpaperBottom)
                XCTAssertGreaterThanOrEqual(min(top, bottom), 3, "\(preset.id)")
            }
        }
    }

    @MainActor
    func testSettingsStoreResolvesTheme() async {
        let settings = SettingsStore(themeID: "forest")
        XCTAssertEqual(settings.theme.name, "フォレスト")
        settings.themeID = "unknown"
        XCTAssertEqual(settings.theme.id, ThemeCatalog.defaultID)
    }
}
