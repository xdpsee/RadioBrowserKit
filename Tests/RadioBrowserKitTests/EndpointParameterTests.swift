import XCTest
@testable import RadioBrowserKit

final class EndpointParameterTests: XCTestCase {
    private let mirror = URL(string: "https://m.example.com")!

    private func makeClient(returning body: String) -> (RadioBrowserClient, StubTransport) {
        let stub = StubTransport { StubTransport.jsonResponse($0, body) }
        return (RadioBrowserClient(config: .init(mirrors: [mirror], userAgent: "t/1"), transport: stub), stub)
    }

    private func queryItems(of url: URL) -> [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems ?? []
    }

    func testListStationsOverridesEncodeAllParams() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.listStations(order: .votes, reverse: false, offset: 20, limit: 0, hideBroken: false)
        XCTAssertEqual(queryItems(of: stub.requestedURLs[0]), [
            URLQueryItem(name: "order", value: "votes"),
            URLQueryItem(name: "reverse", value: "false"),
            URLQueryItem(name: "offset", value: "20"),
            URLQueryItem(name: "limit", value: "0"),
            URLQueryItem(name: "hidebroken", value: "false"),
        ])
    }

    func testSearchCarriesGeoAndHttpsFilters() async throws {
        let (client, stub) = makeClient(returning: "[]")
        var q = StationQuery()
        q.geoLat = 12.5
        q.geoLong = -3.25
        q.geoDistance = 50
        q.hasGeoInfo = true
        q.isHTTPS = false
        _ = try await client.searchStations(q)
        let items = queryItems(of: stub.requestedURLs[0])
        XCTAssertTrue(items.contains(URLQueryItem(name: "geo_lat", value: "12.5")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "geo_long", value: "-3.25")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "geo_distance", value: "50.0")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "has_geo_info", value: "true")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "is_https", value: "false")))
    }

    func testBrokenStationsDefaults() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.brokenStations()
        XCTAssertEqual(queryItems(of: stub.requestedURLs[0]), [
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "limit", value: "100"),
        ])
    }

    func testStationsWithEmptyUUIDListShortCircuits() async throws {
        let (client, stub) = makeClient(returning: "[]")
        let result = try await client.stations(uuids: [])
        XCTAssertEqual(result, [])
        XCTAssertTrue(stub.requestedURLs.isEmpty)
    }

    func testCheckStepsWithEmptyUUIDListShortCircuits() async throws {
        let (client, stub) = makeClient(returning: #"[]"#)
        let result = try await client.checkSteps(uuids: [])
        XCTAssertEqual(result, [])
        XCTAssertTrue(stub.requestedURLs.isEmpty)
    }

    func testCheckStepsDecodesRealPayload() async throws {
        let body = #"[{"stepuuid":"9f2ef9dd-f7a1-476c-8a38-41e7480dc5a1","parent_stepuuid":null,"checkuuid":"14501acd-5ea4-4731-bd20-128849adf1fa","stationuuid":"78012206-1aa1-11e9-a80b-52543be04c81","url":"https://mangoradio.stream.laut.fm/mangoradio","urltype":"STREAM","error":null,"creation_iso8601":"2026-09-20T21:39:38Z"}]"#
        let (client, _) = makeClient(returning: body)
        let steps = try await client.checkSteps(uuids: ["s1"])
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].urlType, "STREAM")
        XCTAssertNotNil(steps[0].creation)
    }

    func testCountriesOrderNameOverride() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.countries(order: .name, limit: 5)
        let items = queryItems(of: stub.requestedURLs[0])
        XCTAssertTrue(items.contains(URLQueryItem(name: "order", value: "name")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "limit", value: "5")))
    }

    func testVoteAndClickShortCircuitDecodesExtraKeys() async throws {
        let body = #"{"ok":true,"message":"vote stored","stationuuid":"s1","name":"X","url":"http://u"}"#
        let (client, _) = makeClient(returning: body)
        let ok = try await client.vote(stationUUID: "s1")
        XCTAssertTrue(ok)
    }
}
