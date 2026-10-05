public struct Stats: Codable, Equatable, Sendable {
    public let supportedVersion: Int?
    public let softwareVersion: String?
    public let status: String?
    public let stations: Int?
    public let stationsBroken: Int?
    public let tags: Int?
    public let clicksLastHour: Int?
    public let clicksLastDay: Int?
    public let languages: Int?
    public let countries: Int?
    
    enum CodingKeys: String, CodingKey {
        case supportedVersion = "supported_version"
        case softwareVersion = "software_version"
        case status
        case stations
        case stationsBroken = "stations_broken"
        case tags
        case clicksLastHour = "clicks_last_hour"
        case clicksLastDay = "clicks_last_day"
        case languages
        case countries
    }
}
