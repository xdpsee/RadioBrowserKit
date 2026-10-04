import XCTest
@testable import RadioBrowserKit

final class URLConstructionTests: XCTestCase {
    private let base = URL(string: "https://m.example.com")!

    private func parsedItems(of url: URL) -> [URLQueryItem]? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
    }

    func testNoQueryProducesNoQuestionMark() {
        let url = RadioBrowserClient.makeURL(base: base, path: "/json/stations/topvote/10", query: [])
        XCTAssertEqual(url.absoluteString, "https://m.example.com/json/stations/topvote/10")
    }

    func testEmptyQueryArrayBehavesLikeNoQuery() {
        let url = RadioBrowserClient.makeURL(base: base, path: "/json/stats", query: [])
        XCTAssertNil(parsedItems(of: url))
    }

    func testQueryValuesArePercentEncodedAndRoundTrip() {
        let items = [
            URLQueryItem(name: "name", value: "big radio"),
            URLQueryItem(name: "tag", value: "爵士&蓝调=100%"),
            URLQueryItem(name: "empty", value: ""),
        ]
        let url = RadioBrowserClient.makeURL(base: base, path: "/json/stations/search", query: items)
        let absolute = url.absoluteString
        XCTAssertTrue(absolute.contains("big%20radio"))
        XCTAssertFalse(absolute.contains("爵士"))
        XCTAssertFalse(absolute.contains("100%&"))
        XCTAssertEqual(parsedItems(of: url), items)
    }

    func testPathSegmentSpecialCharactersAreEncoded() {
        let url = RadioBrowserClient.makeURL(base: base, path: "/json/stations/byuuid/a b/c?", query: [])
        XCTAssertTrue(url.absoluteString.hasPrefix("https://m.example.com/json/stations/byuuid/"))
        // 空格必须百分号编码;斜杠作为路径分隔符保留
        XCTAssertTrue(url.absoluteString.contains("a%20b"))
        XCTAssertFalse(url.absoluteString.contains(" "))
    }
}
