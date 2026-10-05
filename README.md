# RadioBrowserKit

[Radio-Browser.info](https://www.radio-browser.info) API 的 Swift 客户端库。

## 安装

```swift
.package(url: "https://github.com/xdpsee/RadioBrowserKit", from: "0.1.0")
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
- 默认轮转 `all.api / de1.api / de2.api` 三个镜像,网络错误或 5xx 自动换镜像重试(最多 2 次);4xx 与解码错误直接抛出。
- 未知 stationuuid:`station(uuid:)` 返回 `nil`;click/vote 对未知 uuid 抛 `.http(404)`。
- 平台:iOS 15+ / macOS 12+。运行集成测试:`RB_INTEGRATION_TESTS=1 swift test --filter IntegrationTests`。
