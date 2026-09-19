import Foundation
import Synchronization
import Testing
@testable import CatalogBuilderCore

@Suite("Rate limiter")
struct RateLimiterTests {
    /// Orologio finto e registratore delle pause richieste.
    final class Harness: Sendable {
        let current = Mutex<Date>(Date(timeIntervalSince1970: 1_000))
        let sleeps = Mutex<[TimeInterval]>([])

        func advance(_ seconds: TimeInterval) { current.withLock { $0 = $0.addingTimeInterval(seconds) } }
        var recorded: [TimeInterval] { sleeps.withLock { $0 } }

        func makeLimiter(interval: TimeInterval) -> RateLimiter {
            RateLimiter(
                minimumInterval: interval,
                now: { self.current.withLock { $0 } },
                sleep: { seconds in
                    self.sleeps.withLock { $0.append(seconds) }
                    self.current.withLock { $0 = $0.addingTimeInterval(seconds) }
                }
            )
        }
    }

    @Test("the first call never sleeps")
    func firstCallImmediate() async throws {
        let harness = Harness()
        let limiter = harness.makeLimiter(interval: 6.5)
        try await limiter.waitTurn()
        #expect(harness.recorded.isEmpty)
    }

    @Test("a second call right after the first sleeps the whole interval")
    func secondCallSleepsFullInterval() async throws {
        let harness = Harness()
        let limiter = harness.makeLimiter(interval: 6.5)
        try await limiter.waitTurn()
        try await limiter.waitTurn()
        #expect(harness.recorded == [6.5])
    }

    @Test("a call after part of the interval sleeps only the remainder")
    func partialWait() async throws {
        let harness = Harness()
        let limiter = harness.makeLimiter(interval: 6.5)
        try await limiter.waitTurn()
        harness.advance(4)
        try await limiter.waitTurn()
        #expect(harness.recorded == [2.5])
    }

    @Test("a call after the full interval does not sleep")
    func noWaitWhenEnoughTimePassed() async throws {
        let harness = Harness()
        let limiter = harness.makeLimiter(interval: 6.5)
        try await limiter.waitTurn()
        harness.advance(10)
        try await limiter.waitTurn()
        #expect(harness.recorded.isEmpty)
    }
}
