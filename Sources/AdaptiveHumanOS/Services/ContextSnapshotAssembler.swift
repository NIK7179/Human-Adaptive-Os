import Foundation

// MARK: - Snapshot assembly (providers → ContextSnapshot → engine)

/// How old an observation may be before the assembler treats it as missing
/// entirely (mirrors signal expiry: 2 × the Section B.8 useful age). Inside
/// the window, the observation keeps its original timestamp so the engine's
/// freshness factor degrades it smoothly.
public struct ProviderStalenessPolicy: Sendable {
    public let weatherMaxAge: TimeInterval
    public let sleepMaxAge: TimeInterval
    public let moodMaxAge: TimeInterval
    public let activityMaxAge: TimeInterval
    public let ambientMaxAge: TimeInterval
    public let interactionMaxAge: TimeInterval

    public init(
        weatherMaxAge: TimeInterval = 2 * 60 * 60,
        sleepMaxAge: TimeInterval = 48 * 60 * 60,
        moodMaxAge: TimeInterval = 8 * 60 * 60,
        activityMaxAge: TimeInterval = 4 * 60 * 60,
        ambientMaxAge: TimeInterval = 60 * 60,
        interactionMaxAge: TimeInterval = 60 * 60
    ) {
        self.weatherMaxAge = weatherMaxAge
        self.sleepMaxAge = sleepMaxAge
        self.moodMaxAge = moodMaxAge
        self.activityMaxAge = activityMaxAge
        self.ambientMaxAge = ambientMaxAge
        self.interactionMaxAge = interactionMaxAge
    }

    public static let production = ProviderStalenessPolicy()
}

/// Per-source outcome of one assembly pass — the Privacy Center's data
/// lineage and the engine explanation's `unavailableSignals` both derive
/// from this.
public struct ProviderReport: Codable, Sendable, Equatable {
    public var weather: ProviderAvailability
    public var sleep: ProviderAvailability
    public var stateOfMind: ProviderAvailability
    public var activity: ProviderAvailability
    public var ambient: ProviderAvailability
    public var interaction: ProviderAvailability

    public init(
        weather: ProviderAvailability = .unavailable,
        sleep: ProviderAvailability = .unavailable,
        stateOfMind: ProviderAvailability = .unavailable,
        activity: ProviderAvailability = .unavailable,
        ambient: ProviderAvailability = .unavailable,
        interaction: ProviderAvailability = .unavailable
    ) {
        self.weather = weather
        self.sleep = sleep
        self.stateOfMind = stateOfMind
        self.activity = activity
        self.ambient = ambient
        self.interaction = interaction
    }
}

public struct AssembledContext: Sendable {
    public let snapshot: ContextSnapshot
    public let report: ProviderReport

    public init(snapshot: ContextSnapshot, report: ProviderReport) {
        self.snapshot = snapshot
        self.report = report
    }
}

/// Builds a `ContextSnapshot` from the five provider seams.
///
/// Guarantees:
/// - One deterministic timestamp per assembly (`clock.now`, captured once).
/// - A failing provider never aborts assembly — its fields stay missing
///   (`nil`, never zero) and the failure is recorded in the report.
/// - `CancellationError` is the one exception: it always propagates.
/// - Observations older than the staleness policy are dropped as missing
///   and reported `.stale`.
/// - Explicit manual mood (a check-in) outranks HealthKit State of Mind.
public struct ContextSnapshotAssembler: Sendable {
    public let weather: any WeatherProviding
    public let health: any HealthDataProviding
    public let ambient: any AmbientContextProviding
    public let interaction: any InteractionFatigueProviding
    public let clock: any AdaptiveClock
    public let calendarEnvironment: FixedCalendarEnvironment
    public let staleness: ProviderStalenessPolicy

    public init(
        weather: any WeatherProviding,
        health: any HealthDataProviding,
        ambient: any AmbientContextProviding,
        interaction: any InteractionFatigueProviding,
        clock: any AdaptiveClock,
        calendarEnvironment: FixedCalendarEnvironment = .utc,
        staleness: ProviderStalenessPolicy = .production
    ) {
        self.weather = weather
        self.health = health
        self.ambient = ambient
        self.interaction = interaction
        self.clock = clock
        self.calendarEnvironment = calendarEnvironment
        self.staleness = staleness
    }

    public func assemble(
        manualMood: MoodObservation? = nil,
        focusGoal: FocusGoal = .none,
        upcomingInterviewMinutes: Double? = nil,
        accessibility: AccessibilityContext = .none,
        power: PowerContext = .nominal,
        isSimulated: Bool = false
    ) async throws -> AssembledContext {
        // Production timestamp policy (B.23A): captured exactly once.
        let now = clock.now
        var report = ProviderReport()

        func fetch<T>(_ operation: () async throws -> T, into slot: inout ProviderAvailability) async throws -> T? {
            try Task.checkCancellation()
            do {
                let value = try await operation()
                slot = .available
                return value
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as ProviderError {
                switch error {
                case .permissionDenied: slot = .permissionDenied
                case .unavailable: slot = .unavailable
                case .networkUnavailable: slot = .networkUnavailable
                }
                return nil
            } catch {
                slot = .unavailable
                return nil
            }
        }
        func fresh<T>(_ value: T?, observedAt: Date?, maxAge: TimeInterval, slot: inout ProviderAvailability) -> T? {
            guard let value, let observedAt else { return value }
            if now.timeIntervalSince(observedAt) > maxAge {
                slot = .stale
                return nil
            }
            return value
        }

        var weatherObservation = try await fetch({ try await weather.currentWeather() }, into: &report.weather)
        weatherObservation = fresh(
            weatherObservation, observedAt: weatherObservation?.observedAt,
            maxAge: staleness.weatherMaxAge, slot: &report.weather
        )

        var sleepObservation: SleepObservation?
        var mindObservation: MoodObservation?
        var activityObservation: ActivityObservation?
        if health.isAvailable {
            sleepObservation = try await fetch({ try await health.recentSleep() }, into: &report.sleep)
            sleepObservation = fresh(
                sleepObservation, observedAt: sleepObservation?.observedAt,
                maxAge: staleness.sleepMaxAge, slot: &report.sleep
            )
            mindObservation = try await fetch({ try await health.recentStateOfMind() }, into: &report.stateOfMind)
            mindObservation = fresh(
                mindObservation, observedAt: mindObservation?.observedAt,
                maxAge: staleness.moodMaxAge, slot: &report.stateOfMind
            )
            activityObservation = try await fetch({ try await health.todayActivity() }, into: &report.activity)
            activityObservation = fresh(
                activityObservation, observedAt: activityObservation?.observedAt,
                maxAge: staleness.activityMaxAge, slot: &report.activity
            )
        }

        var ambientObservation = try await fetch({ try await ambient.currentAmbientContext() }, into: &report.ambient)
        ambientObservation = fresh(
            ambientObservation, observedAt: ambientObservation?.observedAt,
            maxAge: staleness.ambientMaxAge, slot: &report.ambient
        )

        var interactionObservation = try await fetch({ try await interaction.currentInteraction() }, into: &report.interaction)
        interactionObservation = fresh(
            interactionObservation, observedAt: interactionObservation?.observedAt,
            maxAge: staleness.interactionMaxAge, slot: &report.interaction
        )

        // Explicit user input outweighs inferred/permissioned sources (B.7).
        let effectiveMood: MoodObservation?
        if let manualMood {
            effectiveMood = manualMood
        } else {
            effectiveMood = mindObservation
        }

        let calendar = calendarEnvironment.calendar
        let snapshot = ContextSnapshot(
            timestamp: now,
            localHour: calendar.component(.hour, from: now),
            dayOfWeek: calendar.component(.weekday, from: now),
            solarPhase: ambientObservation?.solarPhase ?? .unavailable,
            weather: weatherObservation?.weather,
            likelyOutdoors: ambientObservation?.likelyOutdoors,
            ambientLight: ambientObservation?.ambientLight,
            mood: effectiveMood?.mood,
            moodValence: effectiveMood?.valence,
            moodEnergy: effectiveMood?.energy,
            moodSource: effectiveMood?.source ?? .unavailable,
            moodReportedAt: effectiveMood?.observedAt,
            sleepDurationHours: sleepObservation?.durationHours,
            sleepQuality: sleepObservation?.quality,
            activityLevel: activityObservation?.level,
            stepCount: activityObservation?.stepCount,
            continuousSessionMinutes: interactionObservation?.continuousSessionMinutes,
            rapidNavigationRate: interactionObservation?.rapidNavigationRate,
            minutesSinceLastBreak: interactionObservation?.minutesSinceLastBreak,
            explicitTiredness: interactionObservation?.explicitTiredness,
            focusGoal: focusGoal,
            upcomingInterviewMinutes: upcomingInterviewMinutes,
            accessibility: accessibility,
            power: power,
            isSimulated: isSimulated
        )
        return AssembledContext(snapshot: snapshot, report: report)
    }
}
