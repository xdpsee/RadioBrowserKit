# RadioBrowserKit 设计文档

日期:2026-10-04
状态:已批准

## 背景与目标

[Radio-Browser.info](https://de1.api.radio-browser.info) 是一个开源社区网络电台目录 API,提供约 5 万个电台的搜索、浏览、排行及点击/投票互动能力,全部为 JSON over HTTPS。

本项目实现一个可复用的 SwiftPM 库 **RadioBrowserKit**,封装该 API 的读取与互动上报能力,供 App 开发者接入。

## 已确认的决策

| 决策点 | 结论 |
|---|---|
| 交付形态 | SwiftPM 库(非完整 App) |
| 平台 | iOS 15+ / macOS 12+,纯 async/await |
| API 范围 | 读取查询 + 互动上报(click/vote);**不含**添加/编辑电台写入接口 |
| 播放器 | 不含,由调用方自行接入 AVFoundation |
| 服务器策略 | 默认 `all.api.radio-browser.info`(DNS 轮询),实现 `/json/servers` 镜像发现 + 故障转移 |
| API 风格 | 单入口 `RadioBrowserClient` actor + 参数结构体;端点方法按功能组用 extension 分文件 |

## 范围外(YAGNI)

- Linux 支持、ICY 实时元数据、播放队列/收藏持久化、`/json/add` 写入接口、Prometheus `/metrics`。

## 包结构

```
RadioBrowserKit/
├── Package.swift
├── Sources/RadioBrowserKit/
│   ├── RadioBrowserClient.swift       # 唯一入口 actor,持有 transport + serverPool
│   ├── ClientConfig.swift             # baseURL / userAgent / 超时 / 重试策略
│   ├── RadioBrowserError.swift        # 错误枚举
│   ├── Core/
│   │   ├── HTTPTransport.swift        # 协议化的 URLSession 封装:GET + JSON 解码
│   │   └── ServerPool.swift           # 镜像发现、轮转、故障转移(独立 actor)
│   ├── Endpoints/
│   │   +Stations.swift                # 列表/排行/byUUID 批量/broken/checkSteps
│   │   +Search.swift                  # searchStations(StationQuery)
│   │   +Directories.swift             # countries/countrycodes/codecs/states/languages/tags/streamingservers/stats
│   │   └ +Interaction.swift           # registerClick / vote
│   └── Models/
│       ├── Station.swift
│       ├── StationQuery.swift
│       ├── DirectoryEntry.swift
│       ├── ServerInfo.swift
│       ├── Stats.swift
│       └── CheckStep.swift
└── Tests/RadioBrowserKitTests/
    ├── QuerySerializationTests.swift
    ├── DecodingTests.swift            # 用真实 API 回放的 JSON fixture
    ├── ServerPoolTests.swift          # 故障转移逻辑
    └── IntegrationTests.swift         # 打 de1 真实服务器,默认 skip,手动开启
```

## 数据模型

### Station

Codable、Identifiable(id = `stationuuid`)。字段与 API 1:1 映射:

- `changeuuid, stationuuid, name, url, urlResolved, homepage, favicon`
- `tags, country, countrycode, state, language, languageCodes, votes, codec, bitrate, hls`
- `lastCheckOk, lastCheckTime, clickTimestamp, clickCount, clickTrend, sslError`
- `geoLat: Double?, geoLong: Double?, geoDistance: Double?, hasExtendedInfo: Bool`
- JSON key 用 `CodingKeys` 映射为 camelCase;时间字段保留原始 String(API 同时提供 `_iso8601` 变体,统一采用带时区的 `_iso8601` 字段解码为 `Date?`)。
- `tags`、`language`、`countrycode` 等逗号分隔字符串保持原样存储,附计算属性 `tagList: [String]`、`languageList: [String]` 做拆分便利。
- `lastCheckOk` 保留 `Int`(0/1),不做 Bool 转换,避免与 API 语义漂移。

### StationQuery

结构体,全成员带默认值,只把**非默认值**编码为 URL query:

- 匹配:`name, country, countrycode, state, language, tag, codec`(各带对应 `Exact` 开关)、`tagList: [String]`(逗号拼接发送)、`geoLat/geoLong/geoDistance`
- 过滤:`bitrateMin, bitrateMax, isHTTPS, hideBroken(默认 true)`
- 分页排序:`order: OrderKey(默认 .clickCount), reverse(默认 true), offset(默认 0), limit(默认 100)`
- `OrderKey` 枚举覆盖 API 全部排序字段(name, clickCount, voteCount, bitrate, changedTime 等)。

### DirectoryEntry

`{ name: String, stationCount: Int }`,所有目录类端点(tags/countries/languages/codecs/states)复用同一模型(各端点 count 字段名不同,在各自方法内解码归一)。

### ServerInfo

`{ name, url, software, policy, version, weight }` —— `/json/servers` 返回项。

## 网络层与服务器故障转移

### HTTPTransport

- 协议 `HTTPTransport`(单方法 `func get<T: Decodable>(_ type: T.Type, url: URL) async throws -> T`),生产实现基于 `URLSession`,测试可注入 stub。
- 必带请求头:`User-Agent`(config 提供,默认 `"RadioBrowserKit/<version>"`,文档要求调用方填自己 App 名)、`Accept: application/json`。
- 请求超时 10 秒;GET 即可覆盖本项目全部端点(click/vote 也用 GET)。

### ServerPool(actor)

1. 初始仅一个成员:config.baseURL(默认 all.api 域名)。
2. 请求失败分类:`URLError`(网络类)与 HTTP 5xx → 可换服务器重试;4xx 与解码错误 → 不重试,直接抛。
3. 触发重试时:`GET <候选服务器>/json/servers` 获取镜像列表,缓存(TTL 1 小时);按 `weight` 加权随机、排除已知失败项,轮转下一台重试。
4. 单请求最多额外尝试 `config.maxServerRetries`(默认 2)次;全部失败抛 `RadioBrowserError.serverUnavailable`。
5. 失败服务器在池内临时拉黑 5 分钟。

## 端点方法清单(RadioBrowserClient)

```swift
// +Search
func searchStations(_ query: StationQuery) async throws -> [Station]
// +Stations
func listStations(order:reverse:offset:limit:) async throws -> [Station]
func station(uuid: String) async throws -> Station?                     // /json/stations/{uuid};API 对未知 uuid 返回空数组 → nil
func stations(uuids: [String]) async throws -> [Station]                // /json/stations/byuuid
func station(url: String) async throws -> [Station]                     // /json/stations/byurl
func topClickedStations(limit:) / topVotedStations(limit:)
func lastClickedStations(limit:) / recentlyChangedStations(limit:)
func brokenStations() / checkSteps(uuids:) async throws -> [CheckStep]
// +Directories
func countries() / countryCodes() / codecs() / states(country:) / languages() / tags() / streamingServers()
    // 目录类方法统一带 order:reverse:offset:limit:hideBroken 参数(均有默认值)
func stats() async throws -> Stats          // /json/stats
// +Interaction
func registerClick(stationUUID: String) async throws   // 每 IP 每电台每日仅计一次(服务端限制)
func vote(stationUUID: String) async throws            // 同 IP 同电台 10 分钟一次(服务端限制)
```

`CheckStep`、`Stats` 为小型 Codable 值类型,字段 1:1 映射。说明:`/json/stations/byname|bytag|bycountry|...` 路径族**有意不封装**——其能力已由 `StationQuery` 的匹配字段 + Exact 开关完整覆盖;仅保留 `station(url:)`,因为按精确 URL 查电台无法用 query 表达。

## 错误处理

```swift
enum RadioBrowserError: LocalizedError {
    case transport(URLError)        // 网络层错误(已重试后仍失败)
    case http(status: Int, body: String?)  // 非 2xx(4xx 不触发换服务器)
    case decoding(Error)            // JSON 结构不符
    case serverUnavailable          // 所有候选镜像均失败
}
```

## 测试策略

- **单测(stub transport)**:StationQuery → URLQueryItem 序列化正确性(默认值省略、Exact 开关、tagList 拼接);各端点 URL 构造;真实 JSON fixture 的解码字段完整性;ServerPool 故障转移(网络错误→换镜像、4xx→不重试、拉黑计时)。
- **集成测试**:`XCTSkipUnless(RB_INTEGRATION_TESTS)` 环境变量开启,对 de1 做搜索/排行/click 真实调用。

## 使用示例

```swift
let client = RadioBrowserClient(config: .init(userAgent: "MyRadioApp/1.0"))
let jazz = try await client.searchStations(.init(tag: "jazz", order: .votes, limit: 30))
let top = try await client.topVotedStations(limit: 10)
try? await client.registerClick(top[0].stationuuid)
```

## 版本与命名

- 库名 `RadioBrowserKit`,target 名 `RadioBrowserKit`,初始版本 0.1.0。
