import XCTest
@testable import RadioBrowserKit

/// 拦截 URLSession 请求,验证 URLSessionTransport 真正设置了协议要求的头。
final class CapturingURLProtocol: URLProtocol {
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("[]".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class URLSessionTransportTests: XCTestCase {
    private func makeTransport() -> URLSessionTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CapturingURLProtocol.self]
        return URLSessionTransport(session: URLSession(configuration: configuration))
    }

    func testGetSendsRequiredHeadersAndReturnsResponse() async throws {
        CapturingURLProtocol.lastRequest = nil
        let url = URL(string: "https://de1.api.radio-browser.info/json/tags?limit=1")!
        let (data, response) = try await makeTransport().get(url, userAgent: "TestApp/1.0")

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), "[]")

        let sent = try XCTUnwrap(CapturingURLProtocol.lastRequest)
        XCTAssertEqual(sent.url, url)
        XCTAssertEqual(sent.value(forHTTPHeaderField: "User-Agent"), "TestApp/1.0")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testClientDefaultUsesURLSessionTransportForLiveRequest() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RB_INTEGRATION_TESTS"] != nil,
            "Set RB_INTEGRATION_TESTS=1 to run live tests"
        )
        // 不注入 stub,走真实 URLSessionTransport 默认路径
        let client = RadioBrowserClient(config: .init(userAgent: "RadioBrowserKit-Integration/0.1"))
        let stats = try await client.stats()
        XCTAssertNotNil(stats.status)
    }
}
