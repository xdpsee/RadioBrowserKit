# RadioBrowserKit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 RadioBrowserKit——封装 Radio-Browser.info API 的 SwiftPM 库(iOS 15+/macOS 12+,纯 async/await,单 Client actor + 镜像故障转移)。

**Architecture:** 单入口 `RadioBrowserClient` actor 持有 `HTTPTransport`(协议化 URLSession 封装,可注入 stub)与 `ServerPool`(镜像种子列表轮转 + 拉黑)。端点方法按功能组用 extension 分文件。详见 spec:`docs/superpowers/specs/2026-10-04-radio-browser-kit-design.md`。

**Tech Stack:** Swift 5.9+(swift-tools-version 5.9,语言模式保持 5,避免 Swift 6 严格并发摩擦)、Foundation(URLSession/JSONDecoder/XCTest)。无第三方依赖。

**重要背景(2026-10-04 对 de1 实测结论,写代码时不要凭旧文档想象):**
- `/json/servers` 只返回 de1 自身 A/AAAA 记录,**不能**用于枚举镜像 → 故障转移靠内置种子列表 `[all.api, de1.api, de2.api]`(nl1/at1/fr1 已宕)。
- 电台时间字段真实格式为无小数秒的 `2026-09-30T22:24:51Z`,取自 `*_iso8601` 键。
- `hls`、`ssl_error`、`lastcheckok` 是 0/1 **整数**;`has_extended_info` 是布尔。
- 目录端点 count 键统一叫 `stationcount`;countries 还带 `iso_3166_1`,states 还带 `country`,languages 还带 `iso_639`(未声明键自动忽略)。
- **未知电台 uuid 查询返回 HTTP 404**(不是空数组 200)→ `station(uuid:)` 需把 404 转 nil。
- click/vote 响应形如 `{"ok":true,"message":"retrieved station url",...}`。
- `streamingservers` 返回空数组(已废弃),不封装。

约定:所有 `Run` 命令在 `/Users/zhenhui/rb` 下执行。测试 fixture 全部来自上述实测 JSON,原样内嵌。

---

### Task 1: Package 脚手架 + Station 模型

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/RadioBrowserKit/Models/Station.swift`
- Create: `Sources/RadioBrowserKit/Core/JSON.swift`
- Test: `Tests/RadioBrowserKitTests/StationTests.swift`

- [ ] **Step 1: 创建 Package.swift 与 .gitignore**

`Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RadioBrowserKit",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "RadioBrowserKit", targets: ["RadioBrowserKit"]),
    ],
    targets: [
        .target(name: "RadioBrowserKit"),
        .testTarget(name: "RadioBrowserKitTests", dependencies: ["RadioBrowserKit"]),
    ]
)
```

`.gitignore`:

```
.build/
.swiftpm/
.DS_Store
DerivedData/
```

- [ ] **Step 2: 写失败测试(真实 de1 响应回放)**

`Tests/RadioBrowserKitTests/StationTests.swift`——fixture 是 2026-10-04 从 `https://de1.api.radio-browser.info/json/stations/topvote?limit=1` 抓取的原样 JSON:

```swift
import XCTest
@testable import RadioBrowserKit

final class StationTests: XCTestCase {
    private static let fixture = #"""
    [{"changeuuid":"f4e60f29-c0c4-4c3d-9db5-a6fc67ed512d","stationuuid":"78012206-1aa1-11e9-a80b-52543be04c81","serveruuid":null,"name":"MANGORADIO","url":"https://mangoradio.stream.laut.fm/mangoradio","url_resolved":"https://mangoradio.stream.laut.fm/mangoradio","homepage":"https://mangoradio.de/","favicon":"https://mangoradio.de/wp-content/uploads/cropped-Logo-192x192.webp","tags":"music,variety","country":"Germany","countrycode":"DE","iso_3166_2":"DE-RP","state":"Rheinland-Pfalz","language":"english,german","languagecodes":"DE,EN","votes":826588,"lastchangetime":"2026-09-30 22:24:51","lastchangetime_iso8601":"2026-09-30T22:24:51Z","codec":"MP3","bitrate":128,"hls":0,"lastcheckok":1,"lastchecktime":"2026-09-30 22:24:55","lastchecktime_iso8601":"2026-09-30T22:24:55Z","lastcheckoktime":"2026-09-30 22:24:55","lastcheckoktime_iso8601":"2026-09-30T22:24:55Z","lastlocalchecktime":"2026-09-30 22:24:55","lastlocalchecktime_iso8601":"2026-09-30T22:24:55Z","clicktimestamp":"2026-10-04 11:17:47","clicktimestamp_iso8601":"2026-10-04T11:17:47Z","clickcount":593,"clicktrend":593,"ssl_error":0,"geo_lat":null,"geo_long":null,"geo_distance":null,"has_extended_info":false}]
    """#

    private func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)!
    }

    func testDecodesRealStation() throws {
        let stations = try JSON.decoder.decode([Station].self, from: Data(Self.fixture.utf8))
        XCTAssertEqual(stations.count, 1)
        let s = try XCTUnwrap(stations.first)
        XCTAssertEqual(s.stationuuid, "78012206-1aa1-11e9-a80b-52543be04c81")
        XCTAssertEqual(s.id, s.stationuuid)
        XCTAssertEqual(s.name, "MANGORADIO")
        XCTAssertEqual(s.urlResolved, "https://mangoradio.stream.laut.fm/mangoradio")
        XCTAssertEqual(s.votes, 826588)
        XCTAssertEqual(s.clickCount, 593)
        XCTAssertEqual(s.clickTrend, 593)
        XCTAssertEqual(s.bitrate, 128)
        XCTAssertEqual(s.codec, "MP3")
        XCTAssertEqual(s.lastCheckOk, 1)
        XCTAssertEqual(s.hls, 0)
        XCTAssertEqual(s.sslError, 0)
        XCTAssertFalse(s.hasExtendedInfo)
        XCTAssertNil(s.geoLat)
        XCTAssertNil(s.serveruuid)
        XCTAssertEqual(s.lastChangeTime, date("2026-09-30T22:24:51Z"))
        XCTAssertEqual(s.lastCheckOkTime, date("2026-09-30T22:24:55Z"))
        XCTAssertEqual(s.clickTimestamp, date("2026-10-04T11:17:47Z"))
        XCTAssertEqual(s.tagList, ["music", "variety"])
        XCTAssertEqual(s.languageList, ["english", "german"])
    }
}
```

- [ ] **Step 3: 跑测试确认失败**

Run: `swift test --filter StationTests`
Expected: 编译失败,`cannot find 'Station' in scope` / `cannot find 'JSON' in scope`

- [ ] **Step 4: 实现 Station 与共享 decoder**

`Sources/RadioBrowserKit/Core/JSON.swift`:

```swift
import Foundation

enum JSON {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: raw) { return date }
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(raw)")
        }
        return decoder
    }()
}
```

`Sources/RadioBrowserKit/Models/Station.swift`:

```swift
import Foundation

public struct Station: Codable, Identifiable, Sendable {
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
    public let iso31662: String
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
```

- [ ] **Step 5: 跑测试确认通过**

Run: `swift test --filter StationTests`
Expected: `Test Suite 'All tests' passed` / `Executed 1 test`

- [ ] **Step 6: Commit**

```bash
git add Package.swift .gitignore Sources Tests
git commit -m "feat: package scaffold with Station model decoding"
```

---

### Task 2: 小模型 DirectoryEntry / Stats / CheckStep / InteractionResult

**Files:**
- Create: `Sources/RadioBrowserKit/Models/DirectoryEntry.swift`
- Create: `Sources/RadioBrowserKit/Models/Stats.swift`
- Create: `Sources/RadioBrowserKit/Models/CheckStep.swift`
- Create: `Sources/RadioBrowserKit/Models/InteractionResult.swift`
- Test: `Tests/RadioBrowserKitTests/SmallModelTests.swift`

- [ ] **Step 1: 写失败测试(fixture 均为实测响应原样)**

`Tests/RadioBrowserKitTests/SmallModelTests.swift`:

```swift
import XCTest
@testable import RadioBrowserKit

final class SmallModelTests: XCTestCase {
    func testDirectoryEntryIgnoresExtraKeys() throws {
        let json = #"""
        [{"name":"The United States Of America","iso_3166_1":"US","stationcount":8369}]
        """#
        let entries = try JSON.decoder.decode([DirectoryEntry].self, from: Data(json.utf8))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "The United States Of America")
        XCTAssertEqual(entries[0].stationCount, 8369)
    }

    func testStats() throws {
        let json = #"""
        {"supported_version":1,"software_version":"0.7.45","status":"OK","stations":60012,"stations_broken":7182,"tags":12446,"clicks_last_hour":13461,"clicks_last_day":273897,"languages":687,"countries":241}
        """#
        let stats = try JSON.decoder.decode(Stats.self, from: Data(json.utf8))
        XCTAssertEqual(stats.supportedVersion, 1)
        XCTAssertEqual(stats.softwareVersion, "0.7.45")
        XCTAssertEqual(stats.status, "OK")
        XCTAssertEqual(stats.stations, 60012)
        XCTAssertEqual(stats.stationsBroken, 7182)
        XCTAssertEqual(stats.clicksLastDay, 273897)
    }

    func testCheckStep() throws {
        let json = #"""
        [{"stepuuid":"9f2ef9dd-f7a1-476c-8a38-41e7480dc5a1","parent_stepuuid":null,"checkuuid":"14501acd-5ea4-4731-bd20-128849adf1fa","stationuuid":"78012206-1aa1-11e9-a80b-52543be04c81","url":"https://mangoradio.stream.laut.fm/mangoradio","urltype":"STREAM","error":null,"creation_iso8601":"2026-09-20T21:39:38Z"}]
        """#
        let steps = try JSON.decoder.decode([CheckStep].self, from: Data(json.utf8))
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].urlType, "STREAM")
        XCTAssertNil(steps[0].parentStepuuid)
        XCTAssertNil(steps[0].error)
        XCTAssertNotNil(steps[0].creation)
    }

    func testInteractionResult() throws {
        let json = #"""
        {"ok":true,"message":"retrieved station url","stationuuid":"78012206-1aa1-11e9-a80b-52543be04c81","name":"MANGORADIO","url":"https://mangoradio.stream.laut.fm/mangoradio"}
        """#
        let result = try JSON.decoder.decode(InteractionResult.self, from: Data(json.utf8))
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.message, "retrieved station url")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter SmallModelTests`
Expected: 编译失败(`cannot find 'DirectoryEntry' in scope` 等)

- [ ] **Step 3: 实现四个模型**

`Sources/RadioBrowserKit/Models/DirectoryEntry.swift`:

```swift
public struct DirectoryEntry: Codable, Sendable {
    public let name: String
    public let stationCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case stationCount = "stationcount"
    }
}
```

`Sources/RadioBrowserKit/Models/Stats.swift`:

```swift
public struct Stats: Codable, Sendable {
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
```

`Sources/RadioBrowserKit/Models/CheckStep.swift`:

```swift
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
```

`Sources/RadioBrowserKit/Models/InteractionResult.swift`:

```swift
public struct InteractionResult: Codable, Sendable {
    public let ok: Bool
    public let message: String?
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter SmallModelTests`
Expected: PASS(4 个测试)

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: DirectoryEntry/Stats/CheckStep/InteractionResult models"
```

---

### Task 3: StationQuery + OrderKey(查询参数序列化)

**Files:**
- Create: `Sources/RadioBrowserKit/Models/StationQuery.swift`
- Test: `Tests/RadioBrowserKitTests/StationQueryTests.swift`

- [ ] **Step 1: 写失败测试**

`Tests/RadioBrowserKitTests/StationQueryTests.swift`:

```swift
import XCTest
@testable import RadioBrowserKit

final class StationQueryTests: XCTestCase {
    func testDefaultsEncodeCoreParams() {
        XCTAssertEqual(StationQuery().queryItems, [
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "hidebroken", value: "true"),
        ])
    }

    func testOptionalFieldsAndExactSwitches() {
        var q = StationQuery()
        q.name = "jazz"
        q.nameExact = true
        q.countrycode = "US"
        q.tag = "jazz"
        q.tagList = ["a", "b"]
        q.bitrateMin = 128
        q.bitrateMax = 320
        q.isHTTPS = true
        q.hasGeoInfo = false
        q.geoLat = 1.5
        q.geoLong = 2.5
        q.geoDistance = 10
        q.limit = 0
        let items = q.queryItems
        XCTAssertTrue(items.contains(URLQueryItem(name: "name", value: "jazz")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "nameExact", value: "true")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "tagList", value: "a,b")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "bitrateMin", value: "128")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "is_https", value: "true")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "has_geo_info", value: "false")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "geo_lat", value: "1.5")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "limit", value: "0")))
        XCTAssertFalse(items.contains(URLQueryItem(name: "tagExact", value: "true")))
        XCTAssertFalse(items.contains(URLQueryItem(name: "state", value: nil)))
    }

    func testOrderKeyRawValues() {
        XCTAssertEqual(OrderKey.clickCount.rawValue, "clickcount")
        XCTAssertEqual(OrderKey.votes.rawValue, "votes")
        XCTAssertEqual(OrderKey.lastCheckTime.rawValue, "lastchecktime")
        XCTAssertEqual(OrderKey.random.rawValue, "random")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter StationQueryTests`
Expected: 编译失败(`cannot find 'StationQuery' in scope`)

- [ ] **Step 3: 实现**

`Sources/RadioBrowserKit/Models/StationQuery.swift`:

```swift
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
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter StationQueryTests`
Expected: PASS(3 个测试)

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: StationQuery parameter serialization and OrderKey"
```

---

### Task 4: RadioBrowserError / ClientConfig / HTTPTransport

**Files:**
- Create: `Sources/RadioBrowserKit/RadioBrowserError.swift`
- Create: `Sources/RadioBrowserKit/ClientConfig.swift`
- Create: `Sources/RadioBrowserKit/Core/HTTPTransport.swift`
- Test: `Tests/RadioBrowserKitTests/ConfigTests.swift`

- [ ] **Step 1: 写失败测试**

`Tests/RadioBrowserKitTests/ConfigTests.swift`:

```swift
import XCTest
@testable import RadioBrowserKit

final class ConfigTests: XCTestCase {
    func testDefaultMirrorsAndUserAgent() {
        let config = ClientConfig()
        XCTAssertEqual(config.mirrors.map(\.host), [
            "all.api.radio-browser.info",
            "de1.api.radio-browser.info",
            "de2.api.radio-browser.info",
        ])
        XCTAssertEqual(config.userAgent, "RadioBrowserKit/0.1.0")
        XCTAssertEqual(config.timeout, 10)
        XCTAssertEqual(config.maxServerRetries, 2)
    }

    func testErrorDescriptionsAreNonEmpty() {
        let errors: [RadioBrowserError] = [
            .transport(URLError(.timedOut)),
            .http(status: 404, body: "nope"),
            .serverUnavailable,
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter ConfigTests`
Expected: 编译失败(`cannot find 'ClientConfig' in scope`)

- [ ] **Step 3: 实现三个文件**

`Sources/RadioBrowserKit/RadioBrowserError.swift`:

```swift
import Foundation

public enum RadioBrowserError: LocalizedError {
    case transport(URLError)
    case http(status: Int, body: String?)
    case decoding(Error)
    case serverUnavailable

    public var errorDescription: String? {
        switch self {
        case .transport(let error): return "Network error: \(error.localizedDescription)"
        case .http(let status, _): return "HTTP status \(status)"
        case .decoding(let error): return "Response decoding failed: \(error.localizedDescription)"
        case .serverUnavailable: return "All mirrors unreachable"
        }
    }
}
```

`Sources/RadioBrowserKit/ClientConfig.swift`:

```swift
import Foundation

public struct ClientConfig: Sendable {
    public static let defaultMirrors: [URL] = [
        "https://all.api.radio-browser.info",
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
```

`Sources/RadioBrowserKit/Core/HTTPTransport.swift`:

```swift
import Foundation

protocol HTTPTransport: Sendable {
    func get(_ url: URL, userAgent: String) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    init(timeout: TimeInterval) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        session = URLSession(configuration: configuration)
    }

    func get(_ url: URL, userAgent: String) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter ConfigTests`
Expected: PASS(2 个测试)

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: RadioBrowserError, ClientConfig, HTTPTransport"
```

---

### Task 5: ServerPool(镜像轮转 + 失败拉黑)

**Files:**
- Create: `Sources/RadioBrowserKit/Core/ServerPool.swift`
- Test: `Tests/RadioBrowserKitTests/ServerPoolTests.swift`

- [ ] **Step 1: 写失败测试**

`Tests/RadioBrowserKitTests/ServerPoolTests.swift`:

```swift
import XCTest
@testable import RadioBrowserKit

final class ServerPoolTests: XCTestCase {
    private let a = URL(string: "https://a.example.com")!
    private let b = URL(string: "https://b.example.com")!
    private let c = URL(string: "https://c.example.com")!

    func testRotation() async {
        let pool = ServerPool(mirrors: [a, b, c])
        let sequence = [await pool.next(), await pool.next(), await pool.next(), await pool.next()]
        XCTAssertEqual(sequence, [a, b, c, a])
    }

    func testFailedMirrorIsSkipped() async {
        let pool = ServerPool(mirrors: [a, b, c])
        _ = await pool.next()          // a
        await pool.markFailed(a)
        XCTAssertEqual(await pool.next(), b)
        XCTAssertEqual(await pool.next(), c)
        XCTAssertEqual(await pool.next(), b)  // a 仍在黑名单,跳过
    }

    func testBlacklistExpires() async {
        var clock = Date(timeIntervalSince1970: 1_000)
        let pool = ServerPool(mirrors: [a, b], blacklistDuration: 300, now: { clock })
        _ = await pool.next()          // a
        await pool.markFailed(a)
        XCTAssertEqual(await pool.next(), b)
        clock += 301
        XCTAssertEqual(await pool.next(), a)
    }

    func testAllBlacklistedReturnsNil() async {
        let pool = ServerPool(mirrors: [a, b])
        await pool.markFailed(a)
        await pool.markFailed(b)
        let next = await pool.next()
        XCTAssertNil(next)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter ServerPoolTests`
Expected: 编译失败(`cannot find 'ServerPool' in scope`)

- [ ] **Step 3: 实现**

`Sources/RadioBrowserKit/Core/ServerPool.swift`:

```swift
import Foundation

actor ServerPool {
    private let mirrors: [URL]
    private let blacklistDuration: TimeInterval
    private let now: @Sendable () -> Date
    private var cursor = 0
    private var failed: [URL: Date] = [:]

    init(
        mirrors: [URL],
        blacklistDuration: TimeInterval = 300,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.mirrors = mirrors
        self.blacklistDuration = blacklistDuration
        self.now = now
    }

    func next() -> URL? {
        let reference = now()
        for _ in 0..<mirrors.count {
            let mirror = mirrors[cursor % mirrors.count]
            cursor += 1
            if let failedAt = failed[mirror], reference.timeIntervalSince(failedAt) < blacklistDuration {
                continue
            }
            return mirror
        }
        return nil
    }

    func markFailed(_ mirror: URL) {
        let reference = now()
        failed[mirror] = reference
        failed = failed.filter { reference.timeIntervalSince($0.value) < blacklistDuration }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter ServerPoolTests`
Expected: PASS(4 个测试)

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: ServerPool mirror rotation and blacklisting"
```

---

### Task 6: RadioBrowserClient 核心 fetch(重试/故障转移分类)

**Files:**
- Create: `Sources/RadioBrowserKit/RadioBrowserClient.swift`
- Create: `Tests/RadioBrowserKitTests/StubTransport.swift`
- Test: `Tests/RadioBrowserKitTests/ClientFetchTests.swift`

- [ ] **Step 1: 写 StubTransport(后续任务复用)**

`Tests/RadioBrowserKitTests/StubTransport.swift`:

```swift
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
```

- [ ] **Step 2: 写失败测试**

`Tests/RadioBrowserKitTests/ClientFetchTests.swift`:

```swift
import XCTest
@testable import RadioBrowserKit

final class ClientFetchTests: XCTestCase {
    private let a = URL(string: "https://a.example.com")!
    private let b = URL(string: "https://b.example.com")!

    private func makeClient(transport: StubTransport, mirrors: [URL]) -> RadioBrowserClient {
        RadioBrowserClient(config: .init(mirrors: mirrors, userAgent: "t/1"), transport: transport)
    }

    func testSuccessDecodesAndBuildsURL() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, "[]") }
        let client = makeClient(transport: stub, mirrors: [a])
        let stations = try await client.fetch([Station].self, path: "/json/stations", query: [
            URLQueryItem(name: "limit", value: "5"),
        ])
        XCTAssertTrue(stations.isEmpty)
        XCTAssertEqual(stub.requestedURLs, [URL(string: "https://a.example.com/json/stations?limit=5")!])
    }

    func testServer5xxSwitchesToNextMirror() async throws {
        let stub = StubTransport { url in
            if url.host == "a.example.com" {
                return StubTransport.jsonResponse(url, status: 500, "")
            }
            return StubTransport.jsonResponse(url, "[]")
        }
        let client = makeClient(transport: stub, mirrors: [a, b])
        _ = try await client.fetch([Station].self, path: "/json/stations")
        XCTAssertEqual(stub.requestedURLs.map(\.host), ["a.example.com", "b.example.com"])
    }

    func testAllMirrorsFailThrowsServerUnavailable() async throws {
        let stub = StubTransport { _ in throw URLError(.notConnectedToInternet) }
        let client = makeClient(transport: stub, mirrors: [a, b])
        do {
            _ = try await client.fetch([Station].self, path: "/json/stations")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .serverUnavailable = error else { return XCTFail("wrong error: \(error)") }
        }
        XCTAssertEqual(stub.requestedURLs.count, 2)
    }

    func testClientErrorDoesNotRetryOrSwitchMirror() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, status: 404, "missing") }
        let client = makeClient(transport: stub, mirrors: [a, b])
        do {
            _ = try await client.fetch([Station].self, path: "/json/stations")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .http(let status, let body) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(status, 404)
            XCTAssertEqual(body, "missing")
        }
        XCTAssertEqual(stub.requestedURLs.count, 1)
    }

    func testDecodingErrorPropagatesWithoutRetry() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, "not-json") }
        let client = makeClient(transport: stub, mirrors: [a])
        do {
            _ = try await client.fetch([Station].self, path: "/json/stations")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .decoding = error else { return XCTFail("wrong error: \(error)") }
        }
        XCTAssertEqual(stub.requestedURLs.count, 1)
    }
}
```

- [ ] **Step 3: 跑测试确认失败**

Run: `swift test --filter ClientFetchTests`
Expected: 编译失败(`cannot find 'RadioBrowserClient' in scope`)

- [ ] **Step 4: 实现**

`Sources/RadioBrowserKit/RadioBrowserClient.swift`:

```swift
import Foundation

public actor RadioBrowserClient {
    let config: ClientConfig
    let transport: any HTTPTransport
    let pool: ServerPool

    public init(config: ClientConfig = ClientConfig(), transport: (any HTTPTransport)? = nil) {
        let transport = transport ?? URLSessionTransport(timeout: config.timeout)
        self.config = config
        self.transport = transport
        self.pool = ServerPool(mirrors: config.mirrors)
    }

    func fetch<T: Decodable>(_ type: T.Type, path: String, query: [URLQueryItem] = []) async throws -> T {
        let attempts = config.maxServerRetries + 1
        for _ in 0..<attempts {
            guard let base = await pool.next() else { break }
            let url = Self.makeURL(base: base, path: path, query: query)
            do {
                let (data, response) = try await transport.get(url, userAgent: config.userAgent)
                if (500...599).contains(response.statusCode) {
                    await pool.markFailed(base)
                    continue
                }
                guard (200..<300).contains(response.statusCode) else {
                    throw RadioBrowserError.http(status: response.statusCode, body: String(data: data, encoding: .utf8))
                }
                return try Self.decode(type, from: data)
            } catch let error as URLError {
                await pool.markFailed(base)
                continue
            }
        }
        throw RadioBrowserError.serverUnavailable
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSON.decoder.decode(type, from: data)
    }

    static func makeURL(base: URL, path: String, query: [URLQueryItem]) -> URL {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }
        return components.url!
    }
}
```

注意:`RadioBrowserError.http/.decoding` 不是 `URLError`,不会被 `catch let error as URLError` 吞掉,会直接向外抛出——这正是"4xx/解码错误不重试"的实现方式。

- [ ] **Step 5: 跑测试确认通过**

Run: `swift test --filter ClientFetchTests`
Expected: PASS(5 个测试)

- [ ] **Step 6: Commit**

```bash
git add Sources Tests
git commit -m "feat: RadioBrowserClient core fetch with mirror failover"
```

---

### Task 7: +Stations / +Search 端点

**Files:**
- Create: `Sources/RadioBrowserKit/Endpoints/+Stations.swift`
- Create: `Sources/RadioBrowserKit/Endpoints/+Search.swift`
- Test: `Tests/RadioBrowserKitTests/StationEndpointTests.swift`

- [ ] **Step 1: 写失败测试**

`Tests/RadioBrowserKitTests/StationEndpointTests.swift`:

```swift
import XCTest
@testable import RadioBrowserKit

final class StationEndpointTests: XCTestCase {
    private let mirror = URL(string: "https://m.example.com")!

    private func makeClient(returning body: String) -> (RadioBrowserClient, StubTransport) {
        let stub = StubTransport { StubTransport.jsonResponse($0, body) }
        return (RadioBrowserClient(config: .init(mirrors: [mirror], userAgent: "t/1"), transport: stub), stub)
    }

    private func queryItems(of url: URL) -> [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems ?? []
    }

    func testListStationsDefaultQuery() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.listStations()
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations")
        XCTAssertEqual(queryItems(of: stub.requestedURLs[0]), [
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "hidebroken", value: "true"),
        ])
    }

    func testSearchEncodesQueryStruct() async throws {
        let (client, stub) = makeClient(returning: "[]")
        var q = StationQuery()
        q.tag = "jazz"
        q.order = .votes
        _ = try await client.searchStations(q)
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations/search")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "tag", value: "jazz")))
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "order", value: "votes")))
    }

    func testStationByUUIDReturnsFirst() async throws {
        let (client, stub) = makeClient(returning: minimalStationJSON)
        let station = try await client.station(uuid: "s1")
        XCTAssertEqual(station?.name, "Test")
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations/s1")
    }

    func testStationByUUIDMaps404ToNil() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, status: 404, "") }
        let client = RadioBrowserClient(config: .init(mirrors: [mirror], userAgent: "t/1"), transport: stub)
        let station = try await client.station(uuid: "missing")
        XCTAssertNil(station)
    }

    func testStationsByUUIDsJoinedComma() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.stations(uuids: ["u1", "u2"])
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations/byuuid")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "uuids", value: "u1,u2")))
    }

    func testStationsByURLUsesQueryParam() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.stations(url: "https://stream.example.com/live")
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations/byurl")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "url", value: "https://stream.example.com/live")))
    }

    func testRankedEndpointPathsCarryLimit() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.topClickedStations(limit: 5)
        _ = try await client.topVotedStations(limit: 7)
        _ = try await client.lastClickedStations()
        _ = try await client.recentlyChangedStations()
        XCTAssertEqual(stub.requestedURLs.map(\.path), [
            "/json/stations/topclick/5",
            "/json/stations/topvote/7",
            "/json/stations/lastclick/10",
            "/json/stations/lastchange/10",
        ])
    }

    func testBrokenStationsQuery() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.brokenStations(offset: 20, limit: 10)
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stations/broken")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "offset", value: "20")))
    }

    func testCheckStepsQuery() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.checkSteps(uuids: ["s1"])
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/checksteps")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "uuids", value: "s1")))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter StationEndpointTests`
Expected: 编译失败(`value of type 'RadioBrowserClient' has no member 'listStations'`)

- [ ] **Step 3: 实现**

`Sources/RadioBrowserKit/Endpoints/+Stations.swift`:

```swift
import Foundation

extension RadioBrowserClient {
    public func listStations(
        order: OrderKey = .clickCount,
        reverse: Bool = true,
        offset: Int = 0,
        limit: Int = 100,
        hideBroken: Bool = true
    ) async throws -> [Station] {
        try await fetch([Station].self, path: "/json/stations", query: [
            URLQueryItem(name: "order", value: order.rawValue),
            URLQueryItem(name: "reverse", value: reverse ? "true" : "false"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "hidebroken", value: hideBroken ? "true" : "false"),
        ])
    }

    public func station(uuid: String) async throws -> Station? {
        do {
            return try await fetch([Station].self, path: "/json/stations/\(uuid)").first
        } catch RadioBrowserError.http(status: 404, _) {
            return nil
        }
    }

    public func stations(uuids: [String]) async throws -> [Station] {
        try await fetch([Station].self, path: "/json/stations/byuuid", query: [
            URLQueryItem(name: "uuids", value: uuids.joined(separator: ",")),
        ])
    }

    public func stations(url: String) async throws -> [Station] {
        try await fetch([Station].self, path: "/json/stations/byurl", query: [
            URLQueryItem(name: "url", value: url),
        ])
    }

    public func topClickedStations(limit: Int = 10) async throws -> [Station] {
        try await ranked("topclick", limit: limit)
    }

    public func topVotedStations(limit: Int = 10) async throws -> [Station] {
        try await ranked("topvote", limit: limit)
    }

    public func lastClickedStations(limit: Int = 10) async throws -> [Station] {
        try await ranked("lastclick", limit: limit)
    }

    public func recentlyChangedStations(limit: Int = 10) async throws -> [Station] {
        try await ranked("lastchange", limit: limit)
    }

    public func brokenStations(offset: Int = 0, limit: Int = 100) async throws -> [Station] {
        try await fetch([Station].self, path: "/json/stations/broken", query: [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    public func checkSteps(uuids: [String]) async throws -> [CheckStep] {
        try await fetch([CheckStep].self, path: "/json/checksteps", query: [
            URLQueryItem(name: "uuids", value: uuids.joined(separator: ",")),
        ])
    }

    private func ranked(_ endpoint: String, limit: Int) async throws -> [Station] {
        try await fetch([Station].self, path: "/json/stations/\(endpoint)/\(limit)")
    }
}
```

`Sources/RadioBrowserKit/Endpoints/+Search.swift`:

```swift
import Foundation

extension RadioBrowserClient {
    public func searchStations(_ query: StationQuery) async throws -> [Station] {
        try await fetch([Station].self, path: "/json/stations/search", query: query.queryItems)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter StationEndpointTests`
Expected: PASS(9 个测试)

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: station listing, ranking, lookup and search endpoints"
```

---

### Task 8: +Directories 端点

**Files:**
- Create: `Sources/RadioBrowserKit/Endpoints/+Directories.swift`
- Test: `Tests/RadioBrowserKitTests/DirectoryEndpointTests.swift`

- [ ] **Step 1: 写失败测试**

`Tests/RadioBrowserKitTests/DirectoryEndpointTests.swift`:

```swift
import XCTest
@testable import RadioBrowserKit

final class DirectoryEndpointTests: XCTestCase {
    private let mirror = URL(string: "https://m.example.com")!

    private func makeClient(returning body: String) -> (RadioBrowserClient, StubTransport) {
        let stub = StubTransport { StubTransport.jsonResponse($0, body) }
        return (RadioBrowserClient(config: .init(mirrors: [mirror], userAgent: "t/1"), transport: stub), stub)
    }

    private func queryItems(of url: URL) -> [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems ?? []
    }

    func testCountriesDefaultQuery() async throws {
        let (client, stub) = makeClient(returning: #"[]"#)
        _ = try await client.countries()
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/countries")
        XCTAssertEqual(queryItems(of: stub.requestedURLs[0]), [
            URLQueryItem(name: "order", value: "stationcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "hidebroken", value: "true"),
        ])
    }

    func testStatesCarriesCountryFilter() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.states(country: "Germany")
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/states")
        XCTAssertTrue(queryItems(of: stub.requestedURLs[0]).contains(URLQueryItem(name: "country", value: "Germany")))
    }

    func testAllDirectoryEndpointsHavePaths() async throws {
        let (client, stub) = makeClient(returning: "[]")
        _ = try await client.countryCodes()
        _ = try await client.codecs()
        _ = try await client.languages()
        _ = try await client.tags()
        XCTAssertEqual(stub.requestedURLs.map(\.path), [
            "/json/countrycodes",
            "/json/codecs",
            "/json/languages",
            "/json/tags",
        ])
    }

    func testStatsEndpoint() async throws {
        let body = #"{"supported_version":1,"software_version":"0.7.45","status":"OK","stations":60012,"stations_broken":7182,"tags":12446,"clicks_last_hour":13461,"clicks_last_day":273897,"languages":687,"countries":241}"#
        let (client, stub) = makeClient(returning: body)
        let stats = try await client.stats()
        XCTAssertEqual(stats.stations, 60012)
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/stats")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter DirectoryEndpointTests`
Expected: 编译失败(`has no member 'countries'`)

- [ ] **Step 3: 实现**

`Sources/RadioBrowserKit/Endpoints/+Directories.swift`:

```swift
import Foundation

public enum DirectoryOrder: String, Sendable {
    case name
    case stationCount = "stationcount"
}

extension RadioBrowserClient {
    public func countries(order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/countries", country: nil, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }

    public func countryCodes(order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/countrycodes", country: nil, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }

    public func codecs(order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/codecs", country: nil, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }

    public func languages(order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/languages", country: nil, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }

    public func tags(order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/tags", country: nil, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }

    public func states(country: String? = nil, order: DirectoryOrder = .stationCount, reverse: Bool = true, offset: Int = 0, limit: Int = 100, hideBroken: Bool = true) async throws -> [DirectoryEntry] {
        try await directories("/json/states", country: country, order: order, reverse: reverse, offset: offset, limit: limit, hideBroken: hideBroken)
    }

    public func stats() async throws -> Stats {
        try await fetch(Stats.self, path: "/json/stats")
    }

    private func directories(
        _ path: String,
        country: String?,
        order: DirectoryOrder,
        reverse: Bool,
        offset: Int,
        limit: Int,
        hideBroken: Bool
    ) async throws -> [DirectoryEntry] {
        var query = [
            URLQueryItem(name: "order", value: order.rawValue),
            URLQueryItem(name: "reverse", value: reverse ? "true" : "false"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "hidebroken", value: hideBroken ? "true" : "false"),
        ]
        if let country {
            query.append(URLQueryItem(name: "country", value: country))
        }
        return try await fetch([DirectoryEntry].self, path: path, query: query)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter DirectoryEndpointTests`
Expected: PASS(4 个测试)

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: directory endpoints and stats"
```

---

### Task 9: +Interaction 端点(click / vote)

**Files:**
- Create: `Sources/RadioBrowserKit/Endpoints/+Interaction.swift`
- Test: `Tests/RadioBrowserKitTests/InteractionEndpointTests.swift`

- [ ] **Step 1: 写失败测试**

`Tests/RadioBrowserKitTests/InteractionEndpointTests.swift`:

```swift
import XCTest
@testable import RadioBrowserKit

final class InteractionEndpointTests: XCTestCase {
    private let mirror = URL(string: "https://m.example.com")!

    private func makeClient(returning body: String) -> (RadioBrowserClient, StubTransport) {
        let stub = StubTransport { StubTransport.jsonResponse($0, body) }
        return (RadioBrowserClient(config: .init(mirrors: [mirror], userAgent: "t/1"), transport: stub), stub)
    }

    func testRegisterClickPathAndResult() async throws {
        let (client, stub) = makeClient(returning: #"{"ok":true,"message":"retrieved station url"}"#)
        let ok = try await client.registerClick(stationUUID: "s1")
        XCTAssertTrue(ok)
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/url/s1")
    }

    func testRegisterClickReturnsFalseWhenNotOk() async throws {
        let (client, _) = makeClient(returning: #"{"ok":false,"message":"too many clicks"}"#)
        let ok = try await client.registerClick(stationUUID: "s1")
        XCTAssertFalse(ok)
    }

    func testVotePath() async throws {
        let (client, stub) = makeClient(returning: #"{"ok":true,"message":"vote stored"}"#)
        let ok = try await client.vote(stationUUID: "s1")
        XCTAssertTrue(ok)
        XCTAssertEqual(stub.requestedURLs.first?.path, "/json/vote/s1")
    }

    func testClickOnUnknownUUIDThrows404() async throws {
        let stub = StubTransport { StubTransport.jsonResponse($0, status: 404, "") }
        let client = RadioBrowserClient(config: .init(mirrors: [mirror], userAgent: "t/1"), transport: stub)
        do {
            _ = try await client.registerClick(stationUUID: "nope")
            XCTFail("should throw")
        } catch let error as RadioBrowserError {
            guard case .http(let status, _) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(status, 404)
        }
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter InteractionEndpointTests`
Expected: 编译失败(`has no member 'registerClick'`)

- [ ] **Step 3: 实现**

`Sources/RadioBrowserKit/Endpoints/+Interaction.swift`:

```swift
import Foundation

extension RadioBrowserClient {
    @discardableResult
    public func registerClick(stationUUID: String) async throws -> Bool {
        let result = try await fetch(InteractionResult.self, path: "/json/url/\(stationUUID)")
        return result.ok
    }

    @discardableResult
    public func vote(stationUUID: String) async throws -> Bool {
        let result = try await fetch(InteractionResult.self, path: "/json/vote/\(stationUUID)")
        return result.ok
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter InteractionEndpointTests`
Expected: PASS(4 个测试)

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: click and vote reporting endpoints"
```

---

### Task 10: 集成测试 + README + 全量回归

**Files:**
- Create: `Tests/RadioBrowserKitTests/IntegrationTests.swift`
- Create: `README.md`

- [ ] **Step 1: 写集成测试(默认 skip,环境变量开启)**

`Tests/RadioBrowserKitTests/IntegrationTests.swift`:

```swift
import XCTest
@testable import RadioBrowserKit

final class IntegrationTests: XCTestCase {
    func testLiveAPI() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RB_INTEGRATION_TESTS"] != nil,
            "Set RB_INTEGRATION_TESTS=1 to run live tests against de1"
        )
        let client = RadioBrowserClient(config: .init(userAgent: "RadioBrowserKit-Integration/0.1"))
        let stats = try await client.stats()
        XCTAssertNotNil(stats.stations)
        XCTAssertGreaterThan(stats.stations ?? 0, 10_000)

        var query = StationQuery()
        query.tag = "jazz"
        query.limit = 3
        let stations = try await client.searchStations(query)
        XCTAssertFalse(stations.isEmpty)
        XCTAssertTrue(stations[0].tagList.contains("jazz") || stations[0].tags.contains("jazz"))

        let top = try await client.topVotedStations(limit: 1)
        XCTAssertNotNil(top.first?.stationuuid)
    }
}
```

- [ ] **Step 2: 跑集成测试(真实网络,验证种子镜像全链路可用)**

Run: `RB_INTEGRATION_TESTS=1 swift test --filter IntegrationTests`
Expected: PASS。若因某镜像 DNS 异常失败,记录失败域名到 commit message,但不擅自修改 `ClientConfig.defaultMirrors`——先向用户报告。

Run: `swift test --filter IntegrationTests`
Expected: SKIP(无环境变量时自动跳过)

- [ ] **Step 3: 写 README.md**

```markdown
# RadioBrowserKit

[Radio-Browser.info](https://www.radio-browser.info) API 的 Swift 客户端库。纯 async/await,无第三方依赖,不含播放器(AVFoundation 自行接入)。

## 安装

```swift
.package(url: "https://github.com/<your-org>/RadioBrowserKit", from: "0.1.0")
```

## 用法

```swift
import RadioBrowserKit

let client = RadioBrowserClient(config: .init(userAgent: "MyRadioApp/1.0"))
var query = StationQuery()
query.tag = "jazz"
query.order = .votes
let stations = try await client.searchStations(query)

let top = try await client.topVotedStations(limit: 10)
try? await client.registerClick(stationUUID: top[0].stationuuid) // 每 IP 每电台每日计一次
```

## 说明

- `User-Agent` 请使用你自己的 App 名(上游 API 的使用规则要求)。
- 默认轮转 `all.api / de1.api / de2.api` 三个镜像,网络错误或 5xx 自动换镜像并重试;未知 stationuuid 的 `station(uuid:)` 返回 `nil`,click/vote 对未知 uuid 抛 `.http(404)`。
- 平台:iOS 15+ / macOS 12+。运行集成测试:`RB_INTEGRATION_TESTS=1 swift test --filter IntegrationTests`。
```

- [ ] **Step 4: 全量回归**

Run: `swift test`
Expected: 全部 PASS,IntegrationTests 为 SKIP。

- [ ] **Step 5: Commit**

```bash
git add Tests README.md
git commit -m "test: live integration tests and README"
```

---

## Self-Review 结论(已执行)

1. **Spec 覆盖:** 模型(Station/Query/DirectoryEntry/Stats/CheckStep/InteractionResult)→ T1-T3;传输层/错误/配置 → T4;故障转移 → T5-T6;全部端点(search/stations/directories/interaction)→ T7-T9;测试策略 → 各任务 + T10。无缺口。
2. **占位符:** 无 TBD/TODO;所有测试均附完整代码与 fixture。
3. **类型一致性:** `fetch<T>(type:path:query:)`、`StubTransport.jsonResponse`、`minimalStationJSON`、`RadioBrowserError.http(status:body:)` 各任务引用签名一致;`stations(url:)`(非 `station(url:)`)已与 spec 对齐。
