import XCTest
@testable import RadioBrowserKit

final class SmallModelTests: XCTestCase {
    func testDirectoryEntryIgnoresExtraKeys() throws {
        let json = #"""
        [{"name":"The United States Of America","iso_3166_1":"US","stationcount":8369}]
        """#
        let entries = try JSON.decoder.decode([DirectoryEntry].self, from: Data(json.utf8))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "The United States Of America")
        XCTAssertEqual(entries[0].stationCount, 8369)
    }

    func testStats() throws {
        let json = #"""
        {"supported_version":1,"software_version":"0.7.45","status":"OK","stations":60012,"stations_broken":7182,"tags":12446,"clicks_last_hour":13461,"clicks_last_day":273897,"languages":687,"countries":241}
        """#
        let stats = try JSON.decoder.decode(Stats.self, from: Data(json.utf8))
        XCTAssertEqual(stats.supportedVersion, 1)
        XCTAssertEqual(stats.softwareVersion, "0.7.45")
        XCTAssertEqual(stats.status, "OK")
        XCTAssertEqual(stats.stations, 60012)
        XCTAssertEqual(stats.stationsBroken, 7182)
        XCTAssertEqual(stats.clicksLastDay, 273897)
    }

    func testCheckStep() throws {
        let json = #"""
        [{"stepuuid":"9f2ef9dd-f7a1-476c-8a38-41e7480dc5a1","parent_stepuuid":null,"checkuuid":"14501acd-5ea4-4731-bd20-128849adf1fa","stationuuid":"78012206-1aa1-11e9-a80b-52543be04c81","url":"https://mangoradio.stream.laut.fm/mangoradio","urltype":"STREAM","error":null,"creation_iso8601":"2026-09-20T21:39:38Z"}]
        """#
        let steps = try JSON.decoder.decode([CheckStep].self, from: Data(json.utf8))
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].urlType, "STREAM")
        XCTAssertNil(steps[0].parentStepuuid)
        XCTAssertNil(steps[0].error)
        XCTAssertNotNil(steps[0].creation)
    }

    func testInteractionResult() throws {
        let json = #"""
        {"ok":true,"message":"retrieved station url","stationuuid":"78012206-1aa1-11e9-a80b-52543be04c81","name":"MANGORADIO","url":"https://mangoradio.stream.laut.fm/mangoradio"}
        """#
        let result = try JSON.decoder.decode(InteractionResult.self, from: Data(json.utf8))
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.message, "retrieved station url")
    }
}
