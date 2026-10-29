import XCTest
@testable import MyHomeCore

final class AppInfoTests: XCTestCase {
    func testDisplayNameIsNotEmpty() {
        XCTAssertFalse(AppInfo.displayName.isEmpty)
    }
}
