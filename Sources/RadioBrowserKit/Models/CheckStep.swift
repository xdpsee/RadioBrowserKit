import Foundation

public struct CheckStep: Codable, Sendable {
    public let stepuuid: String
    public let parentStepuuid: String?
    public let checkuuid: String
    public let stationuuid: String
    public let url: String
    public let urlType: String
    public let error: String?
    public let creation: Date?

    enum CodingKeys: String, CodingKey {
        case stepuuid, checkuuid, stationuuid, url, error
        case parentStepuuid = "parent_stepuuid"
        case urlType = "urltype"
        case creation = "creation_iso8601"
    }
}
