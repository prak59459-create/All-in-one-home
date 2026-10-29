import Foundation
import XCTest
@testable import MyHomeCore

final class ColorCodingTests: XCTestCase {
    func testHexStringRoundTripsOpaqueColor() {
        let color = RGBAColor(hex: 0xF05138)
        XCTAssertEqual(color.hexString, "#F05138")
        XCTAssertEqual(RGBAColor(hexString: "#F05138"), color)
    }

    func testHexStringKeepsAlpha() {
        let color = RGBAColor(hex: 0x112233, alpha: 128.0 / 255.0)
        XCTAssertEqual(color.hexString, "#11223380")
        XCTAssertEqual(RGBAColor(hexString: "#11223380"), color)
    }

    func testHexStringAcceptsLowercase() {
        XCTAssertEqual(RGBAColor(hexString: "#a5b4fc"), RGBAColor(hex: 0xA5B4FC))
    }

    func testHexStringRejectsInvalidText() {
        let invalid: [String] = ["", "#", "F05138", "#F0513", "#F051388", "#GG5138", "#+05138", "#-05138", "# F0513", "#ＦＦＦＦＦＦ"]
        for text in invalid {
            XCTAssertNil(RGBAColor(hexString: text), text)
        }
    }

    func testAllDefaultColorsRoundTrip() {
        let layout: HomeLayout = DefaultLayout.make()
        for item in layout.pages.flatMap(\.items) + layout.dock {
            XCTAssertEqual(RGBAColor(hexString: item.tint.hexString), item.tint, item.id)
        }
    }

    func testColorDecodingRejectsWrongFormat() {
        let data: Data = PersistenceFixtures.json("[\"blue\"]")
        XCTAssertThrowsError(try JSONDecoder().decode([RGBAColor].self, from: data))
    }
}
