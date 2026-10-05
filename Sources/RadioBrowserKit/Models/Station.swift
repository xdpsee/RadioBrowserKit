import Foundation

public struct Station: Codable, Identifiable, Equatable, Sendable {
    public let changeuuid: String
    public let stationuuid: String
    public let serveruuid: String?
    public let name: String
    public let url: String
    public let urlResolved: String
    public let homepage: String
    public let favicon: String
    public let tags: String
    public let country: String
    public let countrycode: String
    /// 实测约 42% 的电台为 null,必须可选。
    public let iso31662: String?
    public let state: String
    public let language: String
    public let languagecodes: String
    public let votes: Int
    public let codec: String
    public let bitrate: Int
    public let hls: Int
    public let lastCheckOk: Int
    public let lastChangeTime: Date?
    public let lastCheckTime: Date?
    public let lastCheckOkTime: Date?
    public let lastLocalCheckTime: Date?
    public let clickTimestamp: Date?
    public let clickCount: Int
    public let clickTrend: Int
    public let sslError: Int
    public let geoLat: Double?
    public let geoLong: Double?
    public let geoDistance: Double?
    public let hasExtendedInfo: Bool
    
    public var id: String { stationuuid }
    public var tagList: [String] { tags.split(separator: ",").map(String.init) }
    public var languageList: [String] { language.split(separator: ",").map(String.init) }
    
    enum CodingKeys: String, CodingKey {
        case changeuuid, stationuuid, serveruuid, name, url, homepage, favicon
        case tags, country, countrycode, state, language, languagecodes, votes
        case codec, bitrate, hls
        case urlResolved = "url_resolved"
        case iso31662 = "iso_3166_2"
        case lastCheckOk = "lastcheckok"
        case lastChangeTime = "lastchangetime_iso8601"
        case lastCheckTime = "lastchecktime_iso8601"
        case lastCheckOkTime = "lastcheckoktime_iso8601"
        case lastLocalCheckTime = "lastlocalchecktime_iso8601"
        case clickTimestamp = "clicktimestamp_iso8601"
        case clickCount = "clickcount"
        case clickTrend = "clicktrend"
        case sslError = "ssl_error"
        case geoLat = "geo_lat"
        case geoLong = "geo_long"
        case geoDistance = "geo_distance"
        case hasExtendedInfo = "has_extended_info"
    }
}
