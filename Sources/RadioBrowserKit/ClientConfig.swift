import Foundation

public struct ClientConfig: Sendable {
    public static let defaultMirrors: [URL] = [
        //"https://all.api.radio-browser.info",
        "https://de1.api.radio-browser.info",
        "https://de2.api.radio-browser.info",
    ].map { URL(string: $0)! }
    
    public var mirrors: [URL]
    public var userAgent: String
    public var timeout: TimeInterval
    public var maxServerRetries: Int
    
    public init(
        mirrors: [URL] = ClientConfig.defaultMirrors,
        userAgent: String = "RadioBrowserKit/0.1.0",
        timeout: TimeInterval = 10,
        maxServerRetries: Int = 2
    ) {
        self.mirrors = mirrors
        self.userAgent = userAgent
        self.timeout = timeout
        self.maxServerRetries = maxServerRetries
    }
}
