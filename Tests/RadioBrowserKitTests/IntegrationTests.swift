import XCTest
@testable import RadioBrowserKit

final class IntegrationTests: XCTestCase {
    func testLiveAPI() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RB_INTEGRATION_TESTS"] != nil,
            "Set RB_INTEGRATION_TESTS=1 to run live tests against de1"
        )
        let client = RadioBrowserClient(config: .init(userAgent: "RadioBrowserKit-Integration/0.1"))

        let stats = try await client.stats()
        XCTAssertNotNil(stats.stations)
        XCTAssertGreaterThan(stats.stations ?? 0, 10_000)

        var query = StationQuery()
        query.tag = "jazz"
        query.limit = 3
        let stations = try await client.searchStations(query)
        XCTAssertFalse(stations.isEmpty)
        XCTAssertTrue(stations[0].tags.contains("jazz"))

        let top = try await client.topVotedStations(limit: 1)
        let station = try XCTUnwrap(top.first)
        let fetched = try await client.station(uuid: station.stationuuid)
        XCTAssertEqual(fetched?.stationuuid, station.stationuuid)

        let batch = try await client.stations(uuids: [station.stationuuid, "definitely-not-a-uuid"])
        XCTAssertEqual(batch.map(\.stationuuid), [station.stationuuid])

        let click = try await client.registerClick(stationUUID: station.stationuuid)
        XCTAssertTrue(click.ok)
        XCTAssertNotNil(click.url)
    }

    func testLive404MapsToNil() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RB_INTEGRATION_TESTS"] != nil)
        let client = RadioBrowserClient(config: .init(userAgent: "RadioBrowserKit-Integration/0.1"))
        let missing = try await client.station(uuid: "00000000-0000-0000-0000-000000000000")
        XCTAssertNil(missing)
    }

    func testLiveWidePageDecodes() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RB_INTEGRATION_TESTS"] != nil)
        let client = RadioBrowserClient(config: .init(userAgent: "RadioBrowserKit-Integration/0.1"))
        // 真实数据约 42% 电台 iso_3166_2 为 null;宽页解码是脏数据回归哨兵
        let page = try await client.listStations(limit: 300)
        XCTAssertEqual(page.count, 300)
        XCTAssertTrue(page.contains { $0.iso31662 == nil })
    }

    func testLiveDirectoryExtras() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RB_INTEGRATION_TESTS"] != nil)
        let client = RadioBrowserClient(config: .init(userAgent: "RadioBrowserKit-Integration/0.1"))
        // 线上全量 countries 的 iso_3166_1 均为两位代码;languages 头部 100 条即有约 78% iso_639 为 null
        let countries = try await client.countries(limit: 50)
        XCTAssertTrue(countries.allSatisfy { $0.iso31661.count == 2 })
        let languages = try await client.languages(limit: 100)
        XCTAssertTrue(languages.contains { $0.iso639 == nil })
        let states = try await client.states(country: "Germany", limit: 10)
        XCTAssertFalse(states.isEmpty)
        XCTAssertTrue(states.allSatisfy { !$0.country.isEmpty })
    }
}
