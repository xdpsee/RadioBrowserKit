import Foundation

extension RadioBrowserClient {
    public func listStations(
        order: OrderKey = .clickCount,
        reverse: Bool = true,
        offset: Int = 0,
        limit: Int = 100,
        hideBroken: Bool = true
    ) async throws -> [Station] {
        try await fetch([Station].self, path: "/json/stations", query: [
            URLQueryItem(name: "order", value: order.rawValue),
            URLQueryItem(name: "reverse", value: reverse ? "true" : "false"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "hidebroken", value: hideBroken ? "true" : "false"),
        ])
    }
    
    public func station(uuid: String) async throws -> Station? {
        try await fetch([Station].self, path: "/json/stations/byuuid/\(uuid)").first
    }
    
    public func stations(uuids: [String]) async throws -> [Station] {
        guard !uuids.isEmpty else { return [] }
        return try await fetch([Station].self, path: "/json/stations/byuuid", query: [
            URLQueryItem(name: "uuids", value: uuids.joined(separator: ",")),
        ])
    }
    
    public func stations(url: String) async throws -> [Station] {
        try await fetch([Station].self, path: "/json/stations/byurl", query: [
            URLQueryItem(name: "url", value: url),
        ])
    }
    
    public func topClickedStations(limit: Int = 10) async throws -> [Station] {
        try await ranked("topclick", limit: limit)
    }
    
    public func topVotedStations(limit: Int = 10) async throws -> [Station] {
        try await ranked("topvote", limit: limit)
    }
    
    public func lastClickedStations(limit: Int = 10) async throws -> [Station] {
        try await ranked("lastclick", limit: limit)
    }
    
    public func recentlyChangedStations(limit: Int = 10) async throws -> [Station] {
        try await ranked("lastchange", limit: limit)
    }
    
    public func brokenStations(offset: Int = 0, limit: Int = 100) async throws -> [Station] {
        try await fetch([Station].self, path: "/json/stations/broken", query: [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }
    
    public func checkSteps(uuids: [String]) async throws -> [CheckStep] {
        guard !uuids.isEmpty else { return [] }
        return try await fetch([CheckStep].self, path: "/json/checksteps", query: [
            URLQueryItem(name: "uuids", value: uuids.joined(separator: ",")),
        ])
    }
    
    private func ranked(_ endpoint: String, limit: Int) async throws -> [Station] {
        try await fetch([Station].self, path: "/json/stations/\(endpoint)/\(limit)")
    }
}
