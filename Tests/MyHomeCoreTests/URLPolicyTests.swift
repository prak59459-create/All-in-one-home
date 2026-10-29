import XCTest
@testable import MyHomeCore

final class URLPolicyTests: XCTestCase {
    func testHTTPSIsAllowedAsSecureWeb() throws {
        let checked: CheckedURL = try allowed(" https://www.Swift.org/documentation ")
        XCTAssertEqual(checked.kind, .secureWeb)
        XCTAssertEqual(checked.destination, "www.swift.org")
        XCTAssertEqual(checked.url.absoluteString, "https://www.Swift.org/documentation")
    }

    func testHTTPIsAllowedButMarkedInsecure() throws {
        let checked: CheckedURL = try allowed("http://example.com")
        XCTAssertEqual(checked.kind, .insecureWeb)
        XCTAssertTrue(checked.confirmationMessage.contains("暗号化されていない"))
    }

    func testAppSchemeIsAllowedWithSchemeAsDestination() throws {
        let checked: CheckedURL = try allowed("shortcuts://")
        XCTAssertEqual(checked.kind, .appScheme)
        XCTAssertEqual(checked.destination, "shortcuts")
    }

    func testDangerousSchemesAreRejectedRegardlessOfCase() {
        XCTAssertEqual(URLPolicy.check("javascript:alert(1)"), .rejected(.blockedScheme("javascript")))
        XCTAssertEqual(URLPolicy.check("JavaScript:alert(1)"), .rejected(.blockedScheme("javascript")))
        XCTAssertEqual(URLPolicy.check("data:text/html,<b>x</b>"), .rejected(.blockedScheme("data")))
        XCTAssertEqual(URLPolicy.check("file:///etc/passwd"), .rejected(.blockedScheme("file")))
        XCTAssertEqual(URLPolicy.check("javascript: alert(1)"), .rejected(.blockedScheme("javascript")))
    }

    func testControlCharactersAreMalformed() {
        XCTAssertEqual(URLPolicy.check("https://example.com/\u{0007}"), .rejected(.malformed))
        XCTAssertEqual(URLPolicy.check("https://example.com/a\tb"), .rejected(.malformed))
    }

    func testLeadingSchemeFollowsRFCSyntax() {
        XCTAssertEqual(URLPolicy.leadingScheme(of: "HTTPS://x"), "https")
        XCTAssertEqual(URLPolicy.leadingScheme(of: "x-callback-url://run"), "x-callback-url")
        XCTAssertNil(URLPolicy.leadingScheme(of: "1abc://x"))
        XCTAssertNil(URLPolicy.leadingScheme(of: "www.apple.com"))
        XCTAssertNil(URLPolicy.leadingScheme(of: "日本:x"))
    }

    func testEmptyAndWhitespaceAreRejected() {
        XCTAssertEqual(URLPolicy.check(""), .rejected(.empty))
        XCTAssertEqual(URLPolicy.check("  \n "), .rejected(.empty))
    }

    func testMissingSchemeIsMalformed() {
        XCTAssertEqual(URLPolicy.check("www.apple.com"), .rejected(.malformed))
    }

    func testSpacesInsideAreMalformed() {
        XCTAssertEqual(URLPolicy.check("https://exa mple.com"), .rejected(.malformed))
    }

    func testWebURLWithoutHostIsRejected() {
        XCTAssertEqual(URLPolicy.check("https://"), .rejected(.missingHost))
        XCTAssertEqual(URLPolicy.check("https:///path"), .rejected(.missingHost))
    }

    func testOverlongURLIsRejected() {
        let long: String = "https://example.com/" + String(repeating: "a", count: URLPolicy.maximumLength)
        XCTAssertEqual(URLPolicy.check(long), .rejected(.tooLong))
    }

    func testEveryRejectionHasMessage() {
        let reasons: [URLRejection] = [.empty, .tooLong, .malformed, .blockedScheme("data"), .missingHost]
        for reason in reasons {
            XCTAssertFalse(reason.message.isEmpty)
        }
    }

    private struct UnexpectedRejection: Error {}

    private func allowed(_ raw: String, file: StaticString = #filePath, line: UInt = #line) throws -> CheckedURL {
        guard case .allowed(let checked) = URLPolicy.check(raw) else {
            XCTFail("許可されるはずの URL が拒否された: \(raw)", file: file, line: line)
            throw UnexpectedRejection()
        }
        return checked
    }
}
