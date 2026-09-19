import Foundation

/// Garantisce almeno `minimumInterval` fra una richiesta e la successiva (policy Open Beauty Facts:
/// 10 ricerche al minuto per IP; qui si tiene un margine). Gli slot vengono prenotati in ordine di
/// arrivo, quindi anche chiamanti concorrenti restano distanziati.
public actor RateLimiter {
    private let minimumInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private var nextAllowed: Date?

    public init(
        minimumInterval: TimeInterval,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(for: .seconds(seconds))
        }
    ) {
        self.minimumInterval = minimumInterval
        self.now = now
        self.sleep = sleep
    }

    public func waitTurn() async throws {
        let current = now()
        let slot = max(current, nextAllowed ?? current)
        nextAllowed = slot.addingTimeInterval(minimumInterval)
        let wait = slot.timeIntervalSince(current)
        if wait > 0 {
            try await sleep(wait)
        }
    }
}
