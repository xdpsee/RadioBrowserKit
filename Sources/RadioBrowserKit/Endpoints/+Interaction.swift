import Foundation

extension RadioBrowserClient {
    @discardableResult
    public func registerClick(stationUUID: String) async throws -> InteractionResult {
        try await fetch(InteractionResult.self, path: "/json/url/\(stationUUID)")
    }
    
    @discardableResult
    public func vote(stationUUID: String) async throws -> Bool {
        let result = try await fetch(InteractionResult.self, path: "/json/vote/\(stationUUID)")
        return result.ok
    }
}
