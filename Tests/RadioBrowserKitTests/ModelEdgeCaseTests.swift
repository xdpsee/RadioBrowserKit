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

    func testCheckStepErrorStringAndAbsentParent() throws {
        let json = #"""
        [{"stepuuid":"s","checkuuid":"c","stationuuid":"st","url":"http://u","urltype":"STREAM","error":"timeout","creation_iso8601":"2026-09-20T21:39:38Z"}]
        """#
        let steps = try JSON.decoder.decode([CheckStep].self, from: Data(json.utf8))
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].error, "timeout")
        XCTAssertNil(steps[0].parentStepuuid)
        XCTAssertNotNil(steps[0].creation)
    }

    func testInteractionResultWithoutMessage() throws {
        let result = try JSON.decoder.decode(InteractionResult.self, from: Data(#"{"ok":true}"#.utf8))
        XCTAssertTrue(result.ok)
        XCTAssertNil(result.message)
    }

    func testDirectoryEntryMinimalShape() throws {
        let entries = try JSON.decoder.decode([DirectoryEntry].self, from: Data(#"[{"name":"rock","stationcount":7}]"#.utf8))
        XCTAssertEqual(entries, [DirectoryEntry(name: "rock", stationCount: 7)])
    }
}
