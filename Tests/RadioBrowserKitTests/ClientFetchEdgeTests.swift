import XCTest
@testable import RadioBrowserKit

final class ClientFetchEdgeTests: XCTestCase {
    private let a = URL(string: "https://a.example.com")!
    private let b = URL(string: "https://b.example.com")!

    private func makeClient(mirrors: [URL], retries: Int? = nil, stub: StubTransport) -> RadioBrowserClient {
        var config = ClientConfig(mirrors: mirrors, userAgent: "t/1")
        if let retries { config.maxServerRetries = retries }
        return RadioBrowserClient(config: config, transport: stub)
    }

    func testZeroRetriesMakesExactlyOneAttempt() async throws {
        let stub = StubTransport { _ in throw URLError(.timedOut) }
        let client = makeClient(mirrors: [a, b], retries: 0, stub: stub)
        do {
            _ = try await client.fetch([Station].self, path: "/json/stations")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .serverUnavailable = error else { return XCTFail("wrong error: \(error)") }
        }
        XCTAssertEqual(stub.requestedURLs.count, 1)
    }

    func testBlacklistCapsRetriesBelowBudget() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, status: 500, "") }
        let client = makeClient(mirrors: [a, b], retries: 5, stub: stub)
        do {
            _ = try await client.fetch([Station].self, path: "/json/stations")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .serverUnavailable = error else { return XCTFail("wrong error: \(error)") }
        }
        // 预算 6 次,但两个镜像都在黑名单后 next() 返回 nil,只发出 2 个请求
        XCTAssertEqual(stub.requestedURLs.count, 2)
    }

    func testMixedNetworkAnd5xxFailuresExhaustMirrors() async throws {
        let stub = StubTransport { url in
            if url.host == "a.example.com" { throw URLError(.timedOut) }
            return StubTransport.jsonResponse(url, status: 503, "")
        }
        let client = makeClient(mirrors: [a, b], stub: stub)
        do {
            _ = try await client.fetch([Station].self, path: "/json/stations")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .serverUnavailable = error else { return XCTFail("wrong error: \(error)") }
        }
        XCTAssertEqual(stub.requestedURLs.map(\.host), ["a.example.com", "b.example.com"])
    }

    func testSucceedsOnSecondMirrorWithRealPayload() async throws {
        let stub = StubTransport { url in
            if url.host == "a.example.com" {
                return StubTransport.jsonResponse(url, status: 500, "")
            }
            return StubTransport.jsonResponse(url, realStationJSON)
        }
        let client = makeClient(mirrors: [a, b], stub: stub)
        let stations = try await client.fetch([Station].self, path: "/json/stations/topvote")
        XCTAssertEqual(stations.count, 1)
        XCTAssertEqual(stations[0].name, "MANGORADIO")
        XCTAssertEqual(stations[0].votes, 826588)
    }

    func testUserAgentPropagatesToTransport() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, "[]") }
        let client = RadioBrowserClient(
            config: .init(mirrors: [a], userAgent: "MyRadio/9.9"),
            transport: stub
        )
        _ = try await client.fetch([Station].self, path: "/json/stats")
        XCTAssertEqual(stub.lastUserAgent, "MyRadio/9.9")
    }

    func testEmptyBodyOn204IsDecodingError() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, status: 204, "") }
        let client = makeClient(mirrors: [a], stub: stub)
        do {
            _ = try await client.fetch([Station].self, path: "/json/stations")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .decoding = error else { return XCTFail("wrong error: \(error)") }
        }
        XCTAssertEqual(stub.requestedURLs.count, 1)
    }

    func testRedirectStatusIsHttpErrorWithoutRetry() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, status: 302, "moved") }
        let client = makeClient(mirrors: [a, b], stub: stub)
        do {
            _ = try await client.fetch([Station].self, path: "/json/stations")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .http(let status, let body) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(status, 302)
            XCTAssertEqual(body, "moved")
        }
        XCTAssertEqual(stub.requestedURLs.count, 1)
    }
}
