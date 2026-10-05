public struct CountryEntry: Codable, Equatable, Sendable {
    public let name: String
    /// 实测全量 242 条均非空。
    public let iso31661: String
    public let stationCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case iso31661 = "iso_3166_1"
        case stationCount = "stationcount"
    }
}

public struct CountryCodeEntry: Codable, Equatable, Sendable {
    public let name: String
    public let stationCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case stationCount = "stationcount"
    }
}

public struct CodecEntry: Codable, Equatable, Sendable {
    public let name: String
    public let stationCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case stationCount = "stationcount"
    }
}

public struct LanguageEntry: Codable, Equatable, Sendable {
    public let name: String
    /// 实测约 80% 为 null。
    public let iso639: String?
    public let stationCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case iso639 = "iso_639"
        case stationCount = "stationcount"
    }
}

public struct TagEntry: Codable, Equatable, Sendable {
    public let name: String
    public let stationCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case stationCount = "stationcount"
    }
}

public struct StateEntry: Codable, Equatable, Sendable {
    public let name: String
    /// 实测全量 4349 条均非空。
    public let country: String
    public let stationCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case country
        case stationCount = "stationcount"
    }
}
