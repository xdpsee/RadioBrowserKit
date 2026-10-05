import XCTest
@testable import RadioBrowserKit

final class ModelEdgeCaseTests: XCTestCase {
    private func firstStation(_ json: String) throws -> Station {
        try XCTUnwrap(JSON.decoder.decode([Station].self, from: Data(json.utf8)).first)
    }

    func testAbsentOptionalKeysDecodeAsNil() throws {
        let json = minimalStationJSON
            .replacingOccurrences(of: "\"serveruuid\":null,", with: "")
            .replacingOccurrences(of: "\"geo_lat\":null,\"geo_long\":null,\"geo_distance\":null,", with: "")
        let s = try firstStation(json)
        XCTAssertNil(s.serveruuid)
        XCTAssertNil(s.geoLat)
        XCTAssertNil(s.geoLong)
        XCTAssertNil(s.geoDistance)
    }

    func testDateWithFractionalSecondsDecodes() throws {
        let json = realStationJSON.replacingOccurrences(
            of: "2026-09-30T22:24:55Z", with: "2026-09-30T22:24:55.385Z"
        )
        let s = try firstStation(json)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let base = formatter.date(from: "2026-09-30T22:24:55Z")!
        XCTAssertEqual(s.lastCheckOkTime!.timeIntervalSince(base), 0.385, accuracy: 0.001)
    }

    func testInvalidDateThrowsDecodingError() {
        let json = realStationJSON.replacingOccurrences(
            of: "2026-09-30T22:24:51Z", with: "2026-13-45T99:99:99Z"
        )
        XCTAssertThrowsError(try JSON.decoder.decode([Station].self, from: Data(json.utf8)))
    }

    func testEmptyTagsYieldEmptyList() throws {
        let json = minimalStationJSON.replacingOccurrences(of: "\"tags\":\"rock,pop\"", with: "\"tags\":\"\"")
        XCTAssertEqual(try firstStation(json).tagList, [])
    }

    func testNullISORegionDecodes() throws {
        // 真实数据约 42% 电台 iso_3166_2 为 null
        let json = realStationJSON.replacingOccurrences(of: "\"iso_3166_2\":\"DE-RP\"", with: "\"iso_3166_2\":null")
        let s = try firstStation(json)
        XCTAssertNil(s.iso31662)
        XCTAssertEqual(s.countrycode, "DE")
    }

    func testStationRoundTripsThroughEncoder() throws {
        let station = try firstStation(minimalStationJSON)
        let redecoded = try JSON.decoder.decode(Station.self, from: JSONEncoder().encode(station))
        XCTAssertEqual(redecoded, station)
    }

    func testEncodedKeysUseAPINameConvention() throws {
        let station = try firstStation(minimalStationJSON)
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(station)) as? [String: Any]
        let keys = Set((object ?? [:]).keys)
        XCTAssertTrue(keys.contains("stationuuid"))
        XCTAssertTrue(keys.contains("url_resolved"))
        XCTAssertTrue(keys.contains("lastcheckok"))
        XCTAssertFalse(keys.contains("urlResolved"))
        XCTAssertFalse(keys.contains("urlresolved"))
    }

    func testStatsMissingKeysDecodeAsNil() throws {
        let stats = try JSON.decoder.decode(Stats.self, from: Data("{}".utf8))
        XCTAssertNil(stats.stations)
        XCTAssertNil(stats.status)
        XCTAssertNil(stats.softwareVersion)
        XCTAssertNil(stats.clicksLastDay)
    }

    func testInteractionResultWithoutMessage() throws {
        let result = try JSON.decoder.decode(InteractionResult.self, from: Data(#"{"ok":true}"#.utf8))
        XCTAssertTrue(result.ok)
        XCTAssertNil(result.message)
        XCTAssertNil(result.stationuuid)
        XCTAssertNil(result.name)
        XCTAssertNil(result.url)
    }

    func testPlainDirectoryEntriesMinimalShape() throws {
        let tags = try JSON.decoder.decode([TagEntry].self, from: Data(#"[{"name":"rock","stationcount":7}]"#.utf8))
        XCTAssertEqual(tags, [TagEntry(name: "rock", stationCount: 7)])
        let codecs = try JSON.decoder.decode([CodecEntry].self, from: Data(#"[{"name":"MP3","stationcount":40450}]"#.utf8))
        XCTAssertEqual(codecs[0].stationCount, 40450)
        let codes = try JSON.decoder.decode([CountryCodeEntry].self, from: Data(#"[{"name":"US","stationcount":7173}]"#.utf8))
        XCTAssertEqual(codes[0].name, "US")
    }

    func testCountryEntryRequiresISOCode() throws {
        // iso_3166_1 在线全量 242/242 非空,声明为必填;缺失属异常载荷
        XCTAssertThrowsError(try JSON.decoder.decode([CountryEntry].self, from: Data(#"[{"name":"Nowhere","stationcount":1}]"#.utf8)))
    }
}
