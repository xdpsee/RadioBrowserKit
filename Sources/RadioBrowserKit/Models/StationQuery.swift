import Foundation

public enum OrderKey: String, Sendable {
    case name, url, homepage, favicon, tags, country, countrycode, state, language, votes, codec, bitrate, hls, random
    case lastCheckOk = "lastcheckok"
    case lastCheckTime = "lastchecktime"
    case clickTimestamp = "clicktimestamp"
    case clickCount = "clickcount"
    case clickTrend = "clicktrend"
}

public struct StationQuery: Sendable {
    public var name: String?
    public var nameExact = false
    public var country: String?
    public var countryExact = false
    public var countrycode: String?
    public var state: String?
    public var stateExact = false
    public var language: String?
    public var languageExact = false
    public var tag: String?
    public var tagExact = false
    public var tagList: [String]?
    public var codec: String?
    public var bitrateMin: Int?
    public var bitrateMax: Int?
    public var isHTTPS: Bool?
    public var hasGeoInfo: Bool?
    public var geoLat: Double?
    public var geoLong: Double?
    public var geoDistance: Double?
    public var order: OrderKey = .clickCount
    public var reverse = true
    public var offset = 0
    public var limit = 100
    public var hideBroken = true

    public init() {}

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        func add(_ key: String, _ value: String?) {
            if let value { items.append(URLQueryItem(name: key, value: value)) }
        }
        func add(_ key: String, _ value: Int?) {
            if let value { items.append(URLQueryItem(name: key, value: String(value))) }
        }
        func add(_ key: String, _ value: Double?) {
            if let value { items.append(URLQueryItem(name: key, value: String(value))) }
        }
        func add(_ key: String, _ value: Bool?) {
            if let value { items.append(URLQueryItem(name: key, value: value ? "true" : "false")) }
        }

        add("name", name)
        if nameExact { add("nameExact", "true") }
        add("country", country)
        if countryExact { add("countryExact", "true") }
        add("countrycode", countrycode)
        add("state", state)
        if stateExact { add("stateExact", "true") }
        add("language", language)
        if languageExact { add("languageExact", "true") }
        add("tag", tag)
        if tagExact { add("tagExact", "true") }
        add("tagList", tagList?.joined(separator: ","))
        add("codec", codec)
        add("bitrateMin", bitrateMin)
        add("bitrateMax", bitrateMax)
        add("is_https", isHTTPS)
        add("has_geo_info", hasGeoInfo)
        add("geo_lat", geoLat)
        add("geo_long", geoLong)
        add("geo_distance", geoDistance)
        add("order", order.rawValue)
        add("reverse", reverse)
        add("offset", offset)
        add("limit", limit)
        add("hidebroken", hideBroken)
        return items
    }
}
