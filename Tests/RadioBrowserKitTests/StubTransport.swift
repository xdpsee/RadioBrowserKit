import Foundation
@testable import RadioBrowserKit

final class StubTransport: HTTPTransport, @unchecked Sendable {
    private(set) var requestedURLs: [URL] = []
    private(set) var lastUserAgent: String?
    let handler: @Sendable (URL) throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URL) throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func get(_ url: URL, userAgent: String) async throws -> (Data, HTTPURLResponse) {
        requestedURLs.append(url)
        lastUserAgent = userAgent
        return try handler(url)
    }

    static func jsonResponse(_ url: URL, status: Int = 200, _ body: String) -> (Data, HTTPURLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!)
    }
}

/// 仅含必填字段的最小合法电台 JSON 数组,端点测试复用。
let minimalStationJSON = #"[{"changeuuid":"c1","stationuuid":"s1","serveruuid":null,"name":"Test","url":"http://u","url_resolved":"http://u","homepage":"","favicon":"","tags":"rock,pop","country":"US","countrycode":"US","iso_3166_2":"","state":"","language":"english","languagecodes":"EN","votes":1,"codec":"MP3","bitrate":0,"hls":0,"lastcheckok":1,"clickcount":0,"clicktrend":0,"ssl_error":0,"geo_lat":null,"geo_long":null,"geo_distance":null,"has_extended_info":false}]"#

/// 2026-10-04 从 de1 /json/stations/topvote 抓取的真实完整电台记录。
let realStationJSON = #"[{"changeuuid":"f4e60f29-c0c4-4c3d-9db5-a6fc67ed512d","stationuuid":"78012206-1aa1-11e9-a80b-52543be04c81","serveruuid":null,"name":"MANGORADIO","url":"https://mangoradio.stream.laut.fm/mangoradio","url_resolved":"https://mangoradio.stream.laut.fm/mangoradio","homepage":"https://mangoradio.de/","favicon":"https://mangoradio.de/wp-content/uploads/cropped-Logo-192x192.webp","tags":"music,variety","country":"Germany","countrycode":"DE","iso_3166_2":"DE-RP","state":"Rheinland-Pfalz","language":"english,german","languagecodes":"DE,EN","votes":826588,"lastchangetime":"2026-09-30 22:24:51","lastchangetime_iso8601":"2026-09-30T22:24:51Z","codec":"MP3","bitrate":128,"hls":0,"lastcheckok":1,"lastchecktime":"2026-09-30 22:24:55","lastchecktime_iso8601":"2026-09-30T22:24:55Z","lastcheckoktime":"2026-09-30 22:24:55","lastcheckoktime_iso8601":"2026-09-30T22:24:55Z","lastlocalchecktime":"2026-09-30 22:24:55","lastlocalchecktime_iso8601":"2026-09-30T22:24:55Z","clicktimestamp":"2026-10-04 11:17:47","clicktimestamp_iso8601":"2026-10-04T11:17:47Z","clickcount":593,"clicktrend":593,"ssl_error":0,"geo_lat":null,"geo_long":null,"geo_distance":null,"has_extended_info":false}]"#