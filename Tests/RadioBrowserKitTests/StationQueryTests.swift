import XCTest
@testable import RadioBrowserKit

final class StationQueryTests: XCTestCase {
    func testDefaultsEncodeCoreParams() {
        XCTAssertEqual(StationQuery().queryItems, [
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "hidebroken", value: "true"),
        ])
    }

    func testOptionalFieldsAndExactSwitches() {
        var q = StationQuery()
        q.name = "jazz"
        q.nameExact = true
        q.countrycode = "US"
        q.tag = "jazz"
        q.tagList = ["a", "b"]
        q.bitrateMin = 128
        q.bitrateMax = 320
        q.isHTTPS = true
        q.hasGeoInfo = false
        q.geoLat = 1.5
        q.geoLong = 2.5
        q.geoDistance = 10
        q.limit = 0
        let items = q.queryItems
        XCTAssertTrue(items.contains(URLQueryItem(name: "name", value: "jazz")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "nameExact", value: "true")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "tagList", value: "a,b")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "bitrateMin", value: "128")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "is_https", value: "true")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "has_geo_info", value: "false")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "geo_lat", value: "1.5")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "limit", value: "0")))
        XCTAssertFalse(items.contains(URLQueryItem(name: "tagExact", value: "true")))
    }

    func testOrderKeyRawValues() {
        XCTAssertEqual(OrderKey.clickCount.rawValue, "clickcount")
        XCTAssertEqual(OrderKey.votes.rawValue, "votes")
        XCTAssertEqual(OrderKey.lastCheckTime.rawValue, "lastchecktime")
        XCTAssertEqual(OrderKey.random.rawValue, "random")
    }
}
