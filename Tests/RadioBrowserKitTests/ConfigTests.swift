import XCTest
@testable import RadioBrowserKit

final class ConfigTests: XCTestCase {
    func testDefaultMirrorsAndUserAgent() {
        let config = ClientConfig()
        XCTAssertEqual(config.mirrors.map(\.host), [
            "all.api.radio-browser.info",
            "de1.api.radio-browser.info",
            "de2.api.radio-browser.info",
        ])
        XCTAssertEqual(config.userAgent, "RadioBrowserKit/0.1.0")
        XCTAssertEqual(config.timeout, 10)
        XCTAssertEqual(config.maxServerRetries, 2)
    }

    func testErrorDescriptionsAreNonEmpty() {
        let errors: [RadioBrowserError] = [
            .transport(URLError(.timedOut)),
            .http(status: 404, body: "nope"),
            .serverUnavailable,
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}
