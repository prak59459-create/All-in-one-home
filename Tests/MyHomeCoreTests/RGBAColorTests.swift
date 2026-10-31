import XCTest
@testable import MyHomeCore

final class RGBAColorTests: XCTestCase {
    func testHexInitializerSplitsComponents() {
        let color = RGBAColor(hex: 0xFF8000)
        XCTAssertEqual(color.red, 1, accuracy: 0.0001)
        XCTAssertEqual(color.green, 128.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(color.blue, 0, accuracy: 0.0001)
        XCTAssertEqual(color.alpha, 1, accuracy: 0.0001)
    }

    func testComponentsAreClamped() {
        let color = RGBAColor(red: 2, green: -1, blue: .nan, alpha: 0.5)
        XCTAssertEqual(color.red, 1)
        XCTAssertEqual(color.green, 0)
        XCTAssertEqual(color.blue, 0)
        XCTAssertEqual(color.alpha, 0.5)
    }

    func testContrastRatioOfBlackAndWhiteIs21() {
        XCTAssertEqual(RGBAColor.black.contrastRatio(with: .white), 21, accuracy: 0.01)
        XCTAssertEqual(RGBAColor.white.contrastRatio(with: .white), 1, accuracy: 0.0001)
    }

    func testBadgeFillsKeepWhiteTextReadable() {
        let badges: [HomeItemBadge] = [.externalLink, .stub, .planned]
        for badge in badges {
            XCTAssertGreaterThanOrEqual(badge.fill.contrastRatio(with: .white), 4.5, "\(badge)")
        }
    }

    func testReadableForegroundPicksHigherContrast() {
        XCTAssertEqual(RGBAColor(hex: 0xF5B700).readableForeground, .black)
        XCTAssertEqual(RGBAColor(hex: 0x24292F).readableForeground, .white)
    }
}
