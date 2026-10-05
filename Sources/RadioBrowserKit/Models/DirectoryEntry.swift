public struct DirectoryEntry: Codable, Equatable, Sendable {
    public let name: String
    public let stationCount: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case stationCount = "stationcount"
    }
}
