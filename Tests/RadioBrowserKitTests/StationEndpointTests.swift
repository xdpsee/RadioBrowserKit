import XCTest
@testable import RadioBrowserKit

final class StationEndpointTests: XCTestCase {
    private let mirror = URL(string: "https://m.example.com")!

    private func makeClient(returning body: String) -> (RadioBrowserClient, StubTransport) {
        let stub = StubTransport { StubTransport.jsonResponse($0, body) }
        return (RadioBrowserClient(config: .init(mirrors: [mirror], userAgent: "t/1"), transport: stub), stub)
    }

    private func queryItems(of url: URL) -> [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems ?? []
    }

    func testListStationsDefaultQuery() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.listStations()
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations")
        XCTAssertEqual(queryItems(of: stub.requestedURLs[0]), [
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "hidebroken", value: "true"),
        ])
    }

    func testSearchEncodesQueryStruct() async throws {
        let (client, stub) = makeClient(returning: "[]")
        var q = StationQuery()
        q.tag = "jazz"
        q.order = .votes
        _ = try await client.searchStations(q)
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations/search")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "tag", value: "jazz")))
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "order", value: "votes")))
    }

    func testStationByUUIDReturnsFirst() async throws {
        let (client, stub) = makeClient(returning: minimalStationJSON)
        let station = try await client.station(uuid: "s1")
        XCTAssertEqual(station?.name, "Test")
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations/s1")
    }

    func testStationByUUIDMaps404ToNil() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, status: 404, "") }
        let client = RadioBrowserClient(config: .init(mirrors: [mirror], userAgent: "t/1"), transport: stub)
        let station = try await client.station(uuid: "missing")
        XCTAssertNil(station)
    }

    func testStationsByUUIDsJoinedComma() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.stations(uuids: ["u1", "u2"])
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations/byuuid")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "uuids", value: "u1,u2")))
    }

    func testStationsByURLUsesQueryParam() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.stations(url: "https://stream.example.com/live")
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations/byurl")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "url", value: "https://stream.example.com/live")))
    }

    func testRankedEndpointPathsCarryLimit() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.topClickedStations(limit: 5)
        _ = try await client.topVotedStations(limit: 7)
        _ = try await client.lastClickedStations()
        _ = try await client.recentlyChangedStations()
        XCTAssertEqual(stub.requestedURLs.map(\.path), [
            "/json/stations/topclick/5",
            "/json/stations/topvote/7",
            "/json/stations/lastclick/10",
            "/json/stations/lastchange/10",
        ])
    }

    func testBrokenStationsQuery() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.brokenStations(offset: 20, limit: 10)
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations/broken")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "offset", value: "20")))
    }

    func testCheckStepsQuery() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.checkSteps(uuids: ["s1"])
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/checksteps")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "uuids", value: "s1")))
    }
}
