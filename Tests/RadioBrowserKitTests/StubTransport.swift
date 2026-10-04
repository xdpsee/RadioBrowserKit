import Foundation
@testable import RadioBrowserKit

final class StubTransport: HTTPTransport, @unchecked Sendable {
    private(set) var requestedURLs: [URL] = []
    let handler: @Sendable (URL) throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URL) throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func get(_ url: URL, userAgent: String) async throws -> (Data, HTTPURLResponse) {
        requestedURLs.append(url)
        return try handler(url)
    }

    static func jsonResponse(_ url: URL, status: Int = 200, _ body: String) -> (Data, HTTPURLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!)
    }
}

/// 仅含必填字段的最小合法电台 JSON 数组,端点测试复用。
let minimalStationJSON = #"[{"changeuuid":"c1","stationuuid":"s1","serveruuid":null,"name":"Test","url":"http://u","url_resolved":"http://u","homepage":"","favicon":"","tags":"rock,pop","country":"US","countrycode":"US","iso_3166_2":"","state":"","language":"english","languagecodes":"EN","votes":1,"codec":"MP3","bitrate":0,"hls":0,"lastcheckok":1,"clickcount":0,"clicktrend":0,"ssl_error":0,"geo_lat":null,"geo_long":null,"geo_distance":null,"has_extended_info":false}]"#
