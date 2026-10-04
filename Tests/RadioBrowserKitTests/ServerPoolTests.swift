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
        let n1 = await pool.next()
        XCTAssertEqual(n1, b)
        let n2 = await pool.next()
        XCTAssertEqual(n2, c)
        let n3 = await pool.next()
        XCTAssertEqual(n3, b)          // a 仍在黑名单,跳过
    }

    func testBlacklistExpires() async {
        var clock = Date(timeIntervalSince1970: 1_000)
        let pool = ServerPool(mirrors: [a, b], blacklistDuration: 300, now: { clock })
        _ = await pool.next()          // a
        await pool.markFailed(a)
        let n1 = await pool.next()
        XCTAssertEqual(n1, b)
        clock += 301
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
}
