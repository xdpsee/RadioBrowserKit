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
            .decoding(NSError(domain: "Test", code: 1)),
            .serverUnavailable,
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testCustomValuesPassThrough() {
        let custom = URL(string: "https://my.mirror.example")!
        let config = ClientConfig(mirrors: [custom], userAgent: "X/1", timeout: 3, maxServerRetries: 5)
        XCTAssertEqual(config.mirrors, [custom])
        XCTAssertEqual(config.userAgent, "X/1")
        XCTAssertEqual(config.timeout, 3)
        XCTAssertEqual(config.maxServerRetries, 5)
    }
}
