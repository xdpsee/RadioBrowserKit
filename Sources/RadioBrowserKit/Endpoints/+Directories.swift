import Foundation

public enum DirectoryOrder: String, Sendable {
    case name
    case stationCount = "stationcount"
}

extension RadioBrowserClient {
    public func countries(order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/countries", country: nil, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }
    
    public func countryCodes(order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/countrycodes", country: nil, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }
    
    public func codecs(order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/codecs", country: nil, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }
    
    public func languages(order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/languages", country: nil, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }
    
    public func tags(order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/tags", country: nil, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }
    
    public func states(country: String? = nil, order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/states", country: country, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }
    
    public func stats() async throws -> Stats {
        try await fetch(Stats.self, path: "/json/stats")
    }
    
    private func directories(
        _ path: String,
        country: String?,
        order: DirectoryOrder,
        reverse: Bool,
        offset: Int,
        limit: Int,
        hideBroken: Bool
    ) async throws -> [DirectoryEntry] {
        var query = [
            URLQueryItem(name: "order", value: order.rawValue),
            URLQueryItem(name: "reverse", value: reverse ? "true" : "false"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "hidebroken", value: hideBroken ? "true" : "false"),
        ]
        
        if let country {
            query.append(URLQueryItem(name: "country", value: country))
        }
        
        return try await fetch([DirectoryEntry].self, path: path, query: query)
    }
}
