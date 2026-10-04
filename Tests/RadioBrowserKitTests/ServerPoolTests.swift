import XCTest
@testable import RadioBrowserKit

/// 可变测试时钟;安全前提是测试串行执行,闭包捕获的是 let 常量引用。
private final class TestClock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_000)
}

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
        let n1 = await pool.next()
        XCTAssertEqual(n1, b)
        let n2 = await pool.next()
        XCTAssertEqual(n2, c)
        let n3 = await pool.next()
        XCTAssertEqual(n3, b)          // a 仍在黑名单,跳过
    }

    func testBlacklistExpires() async {
        let clock = TestClock()
        let pool = ServerPool(mirrors: [a, b], blacklistDuration: 300, now: { clock.date })
        _ = await pool.next()          // a
        await pool.markFailed(a)
        let n1 = await pool.next()
        XCTAssertEqual(n1, b)
        clock.date += 301
        let n2 = await pool.next()
        XCTAssertEqual(n2, a)
    }

    func testAllBlacklistedReturnsNil() async {
        let pool = ServerPool(mirrors: [a, b])
        await pool.markFailed(a)
        await pool.markFailed(b)
        let next = await pool.next()
        XCTAssertNil(next)
    }

    func testSingleMirrorRecoversAfterBlacklistExpiry() async {
        let clock = TestClock()
        let pool = ServerPool(mirrors: [a], blacklistDuration: 300, now: { clock.date })
        let n1 = await pool.next()
        XCTAssertEqual(n1, a)
        await pool.markFailed(a)
        let n2 = await pool.next()
        XCTAssertNil(n2)
        clock.date += 301
        let n3 = await pool.next()
        XCTAssertEqual(n3, a)
    }

    func testMarkFailedResetsBlacklistWindow() async {
        let clock = TestClock()
        let pool = ServerPool(mirrors: [a, b], blacklistDuration: 300, now: { clock.date })
        _ = await pool.next()          // a
        await pool.markFailed(a)       // t=1000
        clock.date += 200              // t=1200
        await pool.markFailed(a)       // 重新计时
        clock.date += 200              // t=1400,距第二次标记仅 200s
        let n1 = await pool.next()
        XCTAssertEqual(n1, b)          // a 仍在黑名单
        clock.date += 150              // t=1550,距第二次标记 350s
        let n2 = await pool.next()
        XCTAssertEqual(n2, a)
    }
}
