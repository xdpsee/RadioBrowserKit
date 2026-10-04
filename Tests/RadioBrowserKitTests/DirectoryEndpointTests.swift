import XCTest
@testable import RadioBrowserKit

final class DirectoryEndpointTests: XCTestCase {
    private let mirror = URL(string: "https://m.example.com")!

    private func makeClient(returning body: String) -> (RadioBrowserClient, StubTransport) {
        let stub = StubTransport { StubTransport.jsonResponse($0, body) }
        return (RadioBrowserClient(config: .init(mirrors: [mirror], userAgent: "t/1"), transport: stub), stub)
    }

    private func queryItems(of url: URL) -> [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems ?? []
    }

    func testCountriesDefaultQuery() async throws {
        let (client, stub) = makeClient(returning: #"[]"#)
        _ = try await client.countries()
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/countries")
        XCTAssertEqual(queryItems(of: stub.requestedURLs[0]), [
            URLQueryItem(name: "order", value: "stationcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "hidebroken", value: "true"),
        ])
    }

    func testStatesCarriesCountryFilter() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.states(country: "Germany")
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/states")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "country", value: "Germany")))
    }

    func testAllDirectoryEndpointsHavePaths() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.countryCodes()
        _ = try await client.codecs()
        _ = try await client.languages()
        _ = try await client.tags()
        XCTAssertEqual(stub.requestedURLs.map(\.path), [
            "/json/countrycodes",
            "/json/codecs",
            "/json/languages",
            "/json/tags",
        ])
    }

    func testStatsEndpoint() async throws {
        let body = #"{"supported_version":1,"software_version":"0.7.45","status":"OK","stations":60012,"stations_broken":7182,"tags":12446,"clicks_last_hour":13461,"clicks_last_day":273897,"languages":687,"countries":241}"#
        let (client, stub) = makeClient(returning: body)
        let stats = try await client.stats()
        XCTAssertEqual(stats.stations, 60012)
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stats")
    }
}
