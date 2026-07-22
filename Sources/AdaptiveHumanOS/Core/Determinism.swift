import Foundation

// MARK: - Deterministic environment dependencies (Section A.1 / B.23A)
//
// Core scoring, confidence, history and explanation logic never calls
// `Date()`, `UUID()`, `Calendar.current`, `TimeZone.current` or
// `Locale.current` directly. Every source of nondeterminism is injected
// through the protocols below. This file is the single sanctioned home of
// the system-backed implementations; a source-scan test asserts that no
// other core file constructs `Date()` or `UUID()`.

public protocol AdaptiveClock: Sendable {
    var now: Date { get }
    func sleep(for duration: Duration) async throws
}

/// Fixed clock for tests and deterministic replays. `sleep` returns
/// immediately so time-driven logic can be stepped manually.
public struct FixedAdaptiveClock: AdaptiveClock {
    public let now: Date

    public init(now: Date) {
        self.now = now
    }

    public func sleep(for duration: Duration) async throws {}
}

/// Production clock. The only permitted `Date()` call site in the package.
public struct SystemAdaptiveClock: AdaptiveClock {
    public init() {}

    public var now: Date { Date() }

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

public protocol AdaptiveIDGenerating: Sendable {
    func makeID() async -> UUID
}

/// Deterministic ID source for tests: hands out a pre-configured sequence.
public actor SequentialIDGenerator: AdaptiveIDGenerating {
    private var identifiers: [UUID]

    public init(identifiers: [UUID]) {
        self.identifiers = identifiers
    }

    public func makeID() async -> UUID {
        precondition(!identifiers.isEmpty, "SequentialIDGenerator exhausted its configured IDs.")
        return identifiers.removeFirst()
    }
}

/// Deterministic unlimited ID source for engine tests: encodes an
/// incrementing counter into the UUID bytes, so evaluations that mint many
/// IDs stay reproducible without pre-configuring a finite list.
public actor CountingIDGenerator: AdaptiveIDGenerating {
    private var counter: UInt64

    public init(startingAt counter: UInt64 = 1) {
        self.counter = counter
    }

    public func makeID() async -> UUID {
        defer { counter += 1 }
        let c = counter
        return UUID(uuid: (
            0xC0, 0x0D, 0xE0, 0x00, 0, 0, 0x40, 0, 0x80, 0,
            UInt8((c >> 40) & 0xFF), UInt8((c >> 32) & 0xFF),
            UInt8((c >> 24) & 0xFF), UInt8((c >> 16) & 0xFF),
            UInt8((c >> 8) & 0xFF), UInt8(c & 0xFF)
        ))
    }
}

/// Production ID source. The only permitted `UUID()` call site in the package.
public struct SystemIDGenerator: AdaptiveIDGenerating {
    public init() {}

    public func makeID() async -> UUID { UUID() }
}

public protocol CalendarProviding: Sendable {
    var calendar: Calendar { get }
}

public protocol TimeZoneProviding: Sendable {
    var timeZone: TimeZone { get }
}

public protocol LocaleProviding: Sendable {
    var locale: Locale { get }
}

/// Fixed calendar/timezone/locale bundle for deterministic tests.
public struct FixedCalendarEnvironment: CalendarProviding, TimeZoneProviding, LocaleProviding {
    public let calendar: Calendar
    public let timeZone: TimeZone
    public let locale: Locale

    public init(calendar: Calendar, timeZone: TimeZone, locale: Locale) {
        var calendar = calendar
        calendar.timeZone = timeZone
        calendar.locale = locale
        self.calendar = calendar
        self.timeZone = timeZone
        self.locale = locale
    }

    /// Gregorian calendar pinned to UTC and en_US_POSIX — the default test environment.
    public static let utc = FixedCalendarEnvironment(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(identifier: "UTC") ?? .gmt,
        locale: Locale(identifier: "en_US_POSIX")
    )
}
