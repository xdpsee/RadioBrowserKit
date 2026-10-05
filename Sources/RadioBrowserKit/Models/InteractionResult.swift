public struct InteractionResult: Codable, Equatable, Sendable {
    public let ok: Bool
    public let message: String?
    public let stationuuid: String?
    public let name: String?
    /// 仅 /json/url 返回:已解析的播放地址。
    public let url: String?

    public init(ok: Bool, message: String? = nil, stationuuid: String? = nil, name: String? = nil, url: String? = nil) {
        self.ok = ok
        self.message = message
        self.stationuuid = stationuuid
        self.name = name
        self.url = url
    }
}
