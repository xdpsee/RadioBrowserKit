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
        failed = failed.filter {
            reference.timeIntervalSince($0.value) < blacklistDuration
        }
        
        for _ in 0..<mirrors.count {
            let mirror = mirrors[cursor % mirrors.count]
            cursor += 1
            if failed[mirror] == nil {
                return mirror
            }
        }
        
        return nil
    }
    
    func markFailed(_ mirror: URL) {
        failed[mirror] = now()
    }
}
