import XCTest
@testable import RadioBrowserKit

final class StationTests: XCTestCase {
    private static let fixture = #"""
    [{"changeuuid":"f4e60f29-c0c4-4c3d-9db5-a6fc67ed512d","stationuuid":"78012206-1aa1-11e9-a80b-52543be04c81","serveruuid":null,"name":"MANGORADIO","url":"https://mangoradio.stream.laut.fm/mangoradio","url_resolved":"https://mangoradio.stream.laut.fm/mangoradio","homepage":"https://mangoradio.de/","favicon":"https://mangoradio.de/wp-content/uploads/cropped-Logo-192x192.webp","tags":"music,variety","country":"Germany","countrycode":"DE","iso_3166_2":"DE-RP","state":"Rheinland-Pfalz","language":"english,german","languagecodes":"DE,EN","votes":826588,"lastchangetime":"2026-09-30 22:24:51","lastchangetime_iso8601":"2026-09-30T22:24:51Z","codec":"MP3","bitrate":128,"hls":0,"lastcheckok":1,"lastchecktime":"2026-09-30 22:24:55","lastchecktime_iso8601":"2026-09-30T22:24:55Z","lastcheckoktime":"2026-09-30 22:24:55","lastcheckoktime_iso8601":"2026-09-30T22:24:55Z","lastlocalchecktime":"2026-09-30 22:24:55","lastlocalchecktime_iso8601":"2026-09-30T22:24:55Z","clicktimestamp":"2026-10-04 11:17:47","clicktimestamp_iso8601":"2026-10-04T11:17:47Z","clickcount":593,"clicktrend":593,"ssl_error":0,"geo_lat":null,"geo_long":null,"geo_distance":null,"has_extended_info":false}]
    """#

    private func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)!
    }

    func testDecodesRealStation() throws {
        let stations = try JSON.decoder.decode([Station].self, from: Data(Self.fixture.utf8))
        XCTAssertEqual(stations.count, 1)
        let s = try XCTUnwrap(stations.first)
        XCTAssertEqual(s.stationuuid, "78012206-1aa1-11e9-a80b-52543be04c81")
        XCTAssertEqual(s.id, s.stationuuid)
        XCTAssertEqual(s.name, "MANGORADIO")
        XCTAssertEqual(s.urlResolved, "https://mangoradio.stream.laut.fm/mangoradio")
        XCTAssertEqual(s.votes, 826588)
        XCTAssertEqual(s.clickCount, 593)
        XCTAssertEqual(s.clickTrend, 593)
        XCTAssertEqual(s.bitrate, 128)
        XCTAssertEqual(s.codec, "MP3")
        XCTAssertEqual(s.lastCheckOk, 1)
        XCTAssertEqual(s.hls, 0)
        XCTAssertEqual(s.sslError, 0)
        XCTAssertFalse(s.hasExtendedInfo)
        XCTAssertNil(s.geoLat)
        XCTAssertNil(s.serveruuid)
        XCTAssertEqual(s.lastChangeTime, date("2026-09-30T22:24:51Z"))
        XCTAssertEqual(s.lastCheckOkTime, date("2026-09-30T22:24:55Z"))
        XCTAssertEqual(s.clickTimestamp, date("2026-10-04T11:17:47Z"))
        XCTAssertEqual(s.tagList, ["music", "variety"])
        XCTAssertEqual(s.languageList, ["english", "german"])
    }
}
