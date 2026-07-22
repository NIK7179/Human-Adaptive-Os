import Foundation

// MARK: - Deterministic simulation-backed providers (Section C.19)
//
// Each provider derives its observations from a `SimulationScenario` and an
// injected clock — pure functions of (scenario, now). The degradation
// scenarios throw the same typed errors real adapters would:
// `missingPermissions` → permissionDenied / unavailable,
// `noNetwork` → networkUnavailable for network-backed sources.

public struct SimulationWeatherProvider: WeatherProviding {
    public let scenario: SimulationScenario
    public let clock: any AdaptiveClock

    public init(scenario: SimulationScenario, clock: any AdaptiveClock) {
        self.scenario = scenario
        self.clock = clock
    }

    public func currentWeather() async throws -> WeatherObservation {
        switch scenario {
        case .noNetwork:
            throw ProviderError.networkUnavailable
        case .missingPermissions:
            throw ProviderError.unavailable
        default:
            let snapshot = scenario.snapshot(at: clock.now)
            guard let weather = snapshot.weather else { throw ProviderError.unavailable }
            return WeatherObservation(weather: weather, observedAt: clock.now)
        }
    }
}

public struct SimulationHealthProvider: HealthDataProviding {
    public let scenario: SimulationScenario
    public let clock: any AdaptiveClock

    public init(scenario: SimulationScenario, clock: any AdaptiveClock) {
        self.scenario = scenario
        self.clock = clock
    }

    public var isAvailable: Bool { true }

    public func requestReadAuthorization() async -> Bool {
        scenario != .missingPermissions
    }

    public func recentSleep() async throws -> SleepObservation {
        if scenario == .missingPermissions { throw ProviderError.permissionDenied }
        let snapshot = scenario.snapshot(at: clock.now)
        guard let hours = snapshot.sleepDurationHours else { throw ProviderError.unavailable }
        return SleepObservation(
            durationHours: hours,
            quality: snapshot.sleepQuality ?? .fair,
            observedAt: clock.now
        )
    }

    public func recentStateOfMind() async throws -> MoodObservation {
        // Scenario moods are manual check-ins, not HealthKit samples —
        // simulation reports State of Mind as absent, exactly like a device
        // with no samples.
        if scenario == .missingPermissions { throw ProviderError.permissionDenied }
        throw ProviderError.unavailable
    }

    public func todayActivity() async throws -> ActivityObservation {
        if scenario == .missingPermissions { throw ProviderError.permissionDenied }
        let snapshot = scenario.snapshot(at: clock.now)
        guard let level = snapshot.activityLevel else { throw ProviderError.unavailable }
        return ActivityObservation(level: level, stepCount: snapshot.stepCount, observedAt: clock.now)
    }
}

public struct SimulationAmbientProvider: AmbientContextProviding {
    public let scenario: SimulationScenario
    public let clock: any AdaptiveClock

    public init(scenario: SimulationScenario, clock: any AdaptiveClock) {
        self.scenario = scenario
        self.clock = clock
    }

    public func currentAmbientContext() async throws -> AmbientObservation {
        let snapshot = scenario.snapshot(at: clock.now)
        return AmbientObservation(
            ambientLight: snapshot.ambientLight,
            likelyOutdoors: snapshot.likelyOutdoors,
            solarPhase: snapshot.solarPhase,
            isApproximation: true,
            observedAt: clock.now
        )
    }
}

public struct SimulationInteractionProvider: InteractionFatigueProviding {
    public let scenario: SimulationScenario
    public let clock: any AdaptiveClock

    public init(scenario: SimulationScenario, clock: any AdaptiveClock) {
        self.scenario = scenario
        self.clock = clock
    }

    public func currentInteraction() async throws -> InteractionObservation {
        let snapshot = scenario.snapshot(at: clock.now)
        return InteractionObservation(
            continuousSessionMinutes: snapshot.continuousSessionMinutes,
            rapidNavigationRate: snapshot.rapidNavigationRate,
            minutesSinceLastBreak: snapshot.minutesSinceLastBreak,
            explicitTiredness: snapshot.explicitTiredness,
            observedAt: clock.now
        )
    }
}

/// Records reminders instead of delivering them — Linux-testable stand-in
/// for the UserNotifications adapter.
public actor SimulationNotificationProvider: NotificationProviding {
    public private(set) var authorizationGranted: Bool
    public private(set) var scheduled: [AdaptiveReminderKind: ScheduledReminder] = [:]

    public init(authorizationGranted: Bool = true) {
        self.authorizationGranted = authorizationGranted
    }

    public func requestAuthorization() async -> Bool {
        authorizationGranted
    }

    public func schedule(_ reminder: ScheduledReminder) async throws {
        guard authorizationGranted else { throw ProviderError.permissionDenied }
        scheduled[reminder.kind] = reminder
    }

    public func cancelReminder(kind: AdaptiveReminderKind) async {
        scheduled[kind] = nil
    }

    public func cancelAllReminders() async {
        scheduled = [:]
    }
}

/// Convenience: the full simulation provider set plus the mood check-in the
/// scenario implies, ready to feed `ContextSnapshotAssembler`.
public struct SimulationProviderSet: Sendable {
    public let weather: SimulationWeatherProvider
    public let health: SimulationHealthProvider
    public let ambient: SimulationAmbientProvider
    public let interaction: SimulationInteractionProvider
    public let manualMood: MoodObservation?
    public let scenario: SimulationScenario

    public init(scenario: SimulationScenario, clock: any AdaptiveClock) {
        self.scenario = scenario
        self.weather = SimulationWeatherProvider(scenario: scenario, clock: clock)
        self.health = SimulationHealthProvider(scenario: scenario, clock: clock)
        self.ambient = SimulationAmbientProvider(scenario: scenario, clock: clock)
        self.interaction = SimulationInteractionProvider(scenario: scenario, clock: clock)
        let snapshot = scenario.snapshot(at: clock.now)
        if snapshot.moodSource == .manualCheckIn,
           snapshot.moodValence != nil || snapshot.moodEnergy != nil {
            self.manualMood = MoodObservation(
                mood: snapshot.mood,
                valence: snapshot.moodValence,
                energy: snapshot.moodEnergy,
                source: .manualCheckIn,
                observedAt: snapshot.moodReportedAt ?? snapshot.timestamp
            )
        } else {
            self.manualMood = nil
        }
    }

    public func assembler(clock: any AdaptiveClock, calendarEnvironment: FixedCalendarEnvironment = .utc) -> ContextSnapshotAssembler {
        ContextSnapshotAssembler(
            weather: weather, health: health, ambient: ambient, interaction: interaction,
            clock: clock, calendarEnvironment: calendarEnvironment
        )
    }
}
