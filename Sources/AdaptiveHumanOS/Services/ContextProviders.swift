import Foundation

// MARK: - Context provider protocols (Section C.7)
//
// The engine never talks to Apple frameworks. These protocols are the only
// seam: platform adapters (WeatherKit, HealthKit, UIKit, UserNotifications)
// live in Xcode-only target folders under App/XcodeTargets and conform to
// the same contracts as the deterministic simulation implementations that
// run on Linux CI.
//
// Every observation carries `observedAt` from an injected clock so
// staleness is decidable and deterministic.

public enum ProviderAvailability: String, Codable, Sendable {
    case available
    case permissionDenied
    case unavailable
    case networkUnavailable
    case stale
}

public enum ProviderError: Error, Equatable, Sendable {
    case permissionDenied
    case unavailable
    case networkUnavailable
}

// MARK: Observations

public struct WeatherObservation: Codable, Sendable, Equatable {
    public let weather: WeatherContext
    public let observedAt: Date

    public init(weather: WeatherContext, observedAt: Date) {
        self.weather = weather
        self.observedAt = observedAt
    }
}

public struct SleepObservation: Codable, Sendable, Equatable {
    public let durationHours: Double
    public let quality: SleepQuality
    public let observedAt: Date

    public init(durationHours: Double, quality: SleepQuality, observedAt: Date) {
        self.durationHours = durationHours
        self.quality = quality
        self.observedAt = observedAt
    }
}

public struct MoodObservation: Codable, Sendable, Equatable {
    public let mood: MoodState?
    public let valence: Double?      // 0.0 ... 1.0
    public let energy: Double?       // 0.0 ... 1.0
    public let source: MoodSource
    public let observedAt: Date

    public init(mood: MoodState?, valence: Double?, energy: Double?, source: MoodSource, observedAt: Date) {
        self.mood = mood
        self.valence = valence
        self.energy = energy
        self.source = source
        self.observedAt = observedAt
    }
}

public struct ActivityObservation: Codable, Sendable, Equatable {
    public let level: ActivityLevel
    public let stepCount: Int?
    public let observedAt: Date

    public init(level: ActivityLevel, stepCount: Int?, observedAt: Date) {
        self.level = level
        self.stepCount = stepCount
        self.observedAt = observedAt
    }
}

public struct AmbientObservation: Codable, Sendable, Equatable {
    public let ambientLight: AmbientLightCategory?
    public let likelyOutdoors: Bool?
    public let solarPhase: SolarPhase
    public let isApproximation: Bool
    public let observedAt: Date

    public init(
        ambientLight: AmbientLightCategory?,
        likelyOutdoors: Bool?,
        solarPhase: SolarPhase,
        isApproximation: Bool,
        observedAt: Date
    ) {
        self.ambientLight = ambientLight
        self.likelyOutdoors = likelyOutdoors
        self.solarPhase = solarPhase
        self.isApproximation = isApproximation
        self.observedAt = observedAt
    }
}

public struct InteractionObservation: Codable, Sendable, Equatable {
    public let continuousSessionMinutes: Double?
    public let rapidNavigationRate: Double?
    public let minutesSinceLastBreak: Double?
    public let explicitTiredness: Double?
    public let observedAt: Date

    public init(
        continuousSessionMinutes: Double?,
        rapidNavigationRate: Double?,
        minutesSinceLastBreak: Double?,
        explicitTiredness: Double?,
        observedAt: Date
    ) {
        self.continuousSessionMinutes = continuousSessionMinutes
        self.rapidNavigationRate = rapidNavigationRate
        self.minutesSinceLastBreak = minutesSinceLastBreak
        self.explicitTiredness = explicitTiredness
        self.observedAt = observedAt
    }
}

// MARK: Protocols

public protocol WeatherProviding: Sendable {
    func currentWeather() async throws -> WeatherObservation
}

public protocol HealthDataProviding: Sendable {
    /// Whether the health store exists on this device at all.
    var isAvailable: Bool { get }
    /// Requests only the read permissions this app uses. Returns whether
    /// the user granted them. Never writes health data.
    func requestReadAuthorization() async -> Bool
    func recentSleep() async throws -> SleepObservation
    func recentStateOfMind() async throws -> MoodObservation
    func todayActivity() async throws -> ActivityObservation
}

public protocol AmbientContextProviding: Sendable {
    /// Public-API-only ambient estimate. Implementations must never touch
    /// private sensor APIs; approximations are flagged as such.
    func currentAmbientContext() async throws -> AmbientObservation
}

public protocol InteractionFatigueProviding: Sendable {
    /// In-app activity only — never other apps, keyboards, microphone or
    /// camera (Section C.7).
    func currentInteraction() async throws -> InteractionObservation
}

public enum AdaptiveReminderKind: String, Codable, CaseIterable, Sendable {
    case takeBreak
    case sleepPreparation
    case moodCheckIn
}

public struct ScheduledReminder: Codable, Sendable, Equatable {
    public let kind: AdaptiveReminderKind
    public let fireAfter: TimeInterval
    public let title: String
    public let body: String

    public init(kind: AdaptiveReminderKind, fireAfter: TimeInterval, title: String, body: String) {
        self.kind = kind
        self.fireAfter = fireAfter
        self.title = title
        self.body = body
    }
}

public protocol NotificationProviding: Sendable {
    /// Ask only after explaining the value in UI. Returns granted state.
    func requestAuthorization() async -> Bool
    /// One reminder per kind; scheduling again replaces it. No manipulative
    /// engagement or retention-only notifications, ever.
    func schedule(_ reminder: ScheduledReminder) async throws
    func cancelReminder(kind: AdaptiveReminderKind) async
    func cancelAllReminders() async
}
