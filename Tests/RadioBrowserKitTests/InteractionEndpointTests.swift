import XCTest
@testable import RadioBrowserKit

final class InteractionEndpointTests: XCTestCase {
    private let mirror = URL(string: "https://m.example.com")!

    private func makeClient(returning body: String) -> (RadioBrowserClient, StubTransport) {
        let stub = StubTransport { StubTransport.jsonResponse($0, body) }
        return (RadioBrowserClient(config: .init(mirrors: [mirror], userAgent: "t/1"), transport: stub), stub)
    }

    func testRegisterClickPathAndResult() async throws {
        let (client, stub) = makeClient(returning: #"{"ok":true,"message":"retrieved station url"}"#)
        let ok = try await client.registerClick(stationUUID: "s1")
        XCTAssertTrue(ok)
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/url/s1")
    }

    func testRegisterClickReturnsFalseWhenNotOk() async throws {
        let (client, _) = makeClient(returning: #"{"ok":false,"message":"too many clicks"}"#)
        let ok = try await client.registerClick(stationUUID: "s1")
        XCTAssertFalse(ok)
    }

    func testVotePath() async throws {
        let (client, stub) = makeClient(returning: #"{"ok":true,"message":"vote stored"}"#)
        let ok = try await client.vote(stationUUID: "s1")
        XCTAssertTrue(ok)
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/vote/s1")
    }

    func testClickOnUnknownUUIDThrows404() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, status: 404, "") }
        let client = RadioBrowserClient(config: .init(mirrors: [mirror], userAgent: "t/1"), transport: stub)
        do {
            _ = try await client.registerClick(stationUUID: "nope")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .http(let status, _) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(status, 404)
        }
    }
}
