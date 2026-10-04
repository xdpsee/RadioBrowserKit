import Foundation

extension RadioBrowserClient {
    public func searchStations(_ query: StationQuery) async throws -> [Station] {
        try await fetch([Station].self, path: "/json/stations/search", query: query.queryItems)
    }
}
