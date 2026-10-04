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

        let ok = try await client.registerClick(stationUUID: station.stationuuid)
        XCTAssertTrue(ok)
    }

    func testLive404MapsToNil() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RB_INTEGRATION_TESTS"] != nil)
        let client = RadioBrowserClient(config: .init(userAgent: "RadioBrowserKit-Integration/0.1"))
        let missing = try await client.station(uuid: "00000000-0000-0000-0000-000000000000")
        XCTAssertNil(missing)
    }
}
