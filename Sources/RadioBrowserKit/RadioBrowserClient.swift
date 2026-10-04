import Foundation

public actor RadioBrowserClient {
    let config: ClientConfig
    let transport: any HTTPTransport
    let pool: ServerPool

    public init(config: ClientConfig = ClientConfig(), transport: (any HTTPTransport)? = nil) {
        self.config = config
        let transport = transport ?? URLSessionTransport(timeout: config.timeout)
        self.transport = transport
        self.pool = ServerPool(mirrors: config.mirrors)
    }

    func fetch<T: Decodable>(_ type: T.Type, path: String, query: [URLQueryItem] = []) async throws -> T {
        let attempts = config.maxServerRetries + 1
        for _ in 0..<attempts {
            guard let base = await pool.next() else { break }
            let url = Self.makeURL(base: base, path: path, query: query)
            let (data, response): (Data, HTTPURLResponse)
            do {
                (data, response) = try await transport.get(url, userAgent: config.userAgent)
            } catch is URLError {
                await pool.markFailed(base)
                continue
            }
            if (500...599).contains(response.statusCode) {
                await pool.markFailed(base)
                continue
            }
            guard (200..<300).contains(response.statusCode) else {
                throw RadioBrowserError.http(status: response.statusCode, body: String(data: data, encoding: .utf8))
            }
            do {
                return try JSON.decoder.decode(type, from: data)
            } catch let decodingError {
                throw RadioBrowserError.decoding(decodingError)
            }
        }
        throw RadioBrowserError.serverUnavailable
    }

    static func makeURL(base: URL, path: String, query: [URLQueryItem]) -> URL {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }
        return components.url!
    }
}
