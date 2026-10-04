import XCTest
@testable import RadioBrowserKit

final class StationTests: XCTestCase {
    private func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)!
    }

    func testDecodesRealStation() throws {
        let stations = try JSON.decoder.decode([Station].self, from: Data(realStationJSON.utf8))
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
