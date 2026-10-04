import XCTest
@testable import RadioBrowserKit

final class ClientFetchTests: XCTestCase {
    private let a = URL(string: "https://a.example.com")!
    private let b = URL(string: "https://b.example.com")!

    private func makeClient(transport: StubTransport, mirrors: [URL]) -> RadioBrowserClient {
        RadioBrowserClient(config: .init(mirrors: mirrors, userAgent: "t/1"), transport: transport)
    }

    func testSuccessDecodesAndBuildsURL() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, "[]") }
        let client = makeClient(transport: stub, mirrors: [a])
        let stations = try await client.fetch([Station].self, path: "/json/stations", query: [
            URLQueryItem(name: "limit", value: "5"),
        ])
        XCTAssertTrue(stations.isEmpty)
        XCTAssertEqual(stub.requestedURLs, [URL(string: "https://a.example.com/json/stations?limit=5")!])
    }

    func testServer5xxSwitchesToNextMirror() async throws {
        let stub = StubTransport { url in
            if url.host == "a.example.com" {
                return StubTransport.jsonResponse(url, status: 500, "")
            }
            return StubTransport.jsonResponse(url, "[]")
        }
        let client = makeClient(transport: stub, mirrors: [a, b])
        _ = try await client.fetch([Station].self, path: "/json/stations")
        XCTAssertEqual(stub.requestedURLs.map(\.host), ["a.example.com", "b.example.com"])
    }

    func testAllMirrorsFailThrowsServerUnavailable() async throws {
        let stub = StubTransport { _ in throw URLError(.notConnectedToInternet) }
        let client = makeClient(transport: stub, mirrors: [a, b])
        do {
            _ = try await client.fetch([Station].self, path: "/json/stations")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .serverUnavailable = error else { return XCTFail("wrong error: \(error)") }
        }
        XCTAssertEqual(stub.requestedURLs.count, 2)
    }

    func testClientErrorDoesNotRetryOrSwitchMirror() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, status: 404, "missing") }
        let client = makeClient(transport: stub, mirrors: [a, b])
        do {
            _ = try await client.fetch([Station].self, path: "/json/stations")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .http(let status, let body) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(status, 404)
            XCTAssertEqual(body, "missing")
        }
        XCTAssertEqual(stub.requestedURLs.count, 1)
    }

    func testDecodingErrorPropagatesWithoutRetry() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, "not-json") }
        let client = makeClient(transport: stub, mirrors: [a])
        do {
            _ = try await client.fetch([Station].self, path: "/json/stations")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .decoding = error else { return XCTFail("wrong error: \(error)") }
        }
        XCTAssertEqual(stub.requestedURLs.count, 1)
    }
}
