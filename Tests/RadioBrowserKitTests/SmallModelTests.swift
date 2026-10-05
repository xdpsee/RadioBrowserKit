import XCTest
@testable import RadioBrowserKit

final class SmallModelTests: XCTestCase {
    func testCountryEntryDecodesLiveShapeAndIgnoresUnknownKeys() throws {
        let json = #"""
        [{"name":"The United States Of America","iso_3166_1":"US","stationcount":8369,"unknown_key":42}]
        """#
        let entries = try JSON.decoder.decode([CountryEntry].self, from: Data(json.utf8))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0], CountryEntry(name: "The United States Of America", iso31661: "US", stationCount: 8369))
    }

    func testLanguageAndStateEntryExtras() throws {
        let languages = try JSON.decoder.decode([LanguageEntry].self, from: Data(#"[{"name":"english","iso_639":"en","stationcount":11894},{"name":"klingon","iso_639":null,"stationcount":3}]"#.utf8))
        XCTAssertEqual(languages[0].iso639, "en")
        XCTAssertNil(languages[1].iso639)

        let states = try JSON.decoder.decode([StateEntry].self, from: Data(#"[{"name":"California","country":"The United States Of America","stationcount":443}]"#.utf8))
        XCTAssertEqual(states[0].country, "The United States Of America")
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

    func testInteractionResult() throws {
        // 线上 /json/url 的真实载荷形状
        let json = #"""
        {"ok":true,"message":"retrieved station url","stationuuid":"78012206-1aa1-11e9-a80b-52543be04c81","name":"MANGORADIO","url":"https://mangoradio.stream.laut.fm/mangoradio"}
        """#
        let result = try JSON.decoder.decode(InteractionResult.self, from: Data(json.utf8))
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.message, "retrieved station url")
        XCTAssertEqual(result.stationuuid, "78012206-1aa1-11e9-a80b-52543be04c81")
        XCTAssertEqual(result.name, "MANGORADIO")
        XCTAssertEqual(result.url, "https://mangoradio.stream.laut.fm/mangoradio")
    }

    func testInteractionResultVoteShape() throws {
        let result = try JSON.decoder.decode(InteractionResult.self, from: Data(#"{"ok":false,"message":"VoteError 'you are voting for the same station too often'"}"#.utf8))
        XCTAssertFalse(result.ok)
        XCTAssertNotNil(result.message)
        XCTAssertNil(result.url)
    }
}
