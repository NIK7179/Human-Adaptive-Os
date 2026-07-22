import Testing
import Foundation
@testable import AdaptiveHumanOS

// MARK: - Test doubles (production protocol conformances)

private struct StubWeatherProvider: WeatherProviding {
    var result: Result<WeatherObservation, ProviderError>
    func currentWeather() async throws -> WeatherObservation { try result.get() }
}

private struct SlowWeatherProvider: WeatherProviding {
    func currentWeather() async throws -> WeatherObservation {
        try await Task.sleep(for: .seconds(30))
        throw ProviderError.unavailable
    }
}

private struct ThrowingHealthProvider: HealthDataProviding {
    var isAvailable: Bool { true }
    func requestReadAuthorization() async -> Bool { false }
    func recentSleep() async throws -> SleepObservation { throw ProviderError.permissionDenied }
    func recentStateOfMind() async throws -> MoodObservation { throw ProviderError.permissionDenied }
    func todayActivity() async throws -> ActivityObservation { throw ProviderError.permissionDenied }
}

/// Provider integration: snapshot assembly, degradation, staleness,
/// cancellation and determinism — all on Linux, no Apple frameworks.
struct ProviderIntegrationTests {
    private let clock = TestSupport.clock

    private func simulationAssembler(_ scenario: SimulationScenario) -> (ContextSnapshotAssembler, SimulationProviderSet) {
        let set = SimulationProviderSet(scenario: scenario, clock: clock)
        return (set.assembler(clock: clock), set)
    }

    // 1. Context snapshot assembly: fields flow through, timestamp comes
    // from the injected clock exactly once, hour/day from the fixed calendar.
    @Test
    func assemblerBuildsSnapshotFromProviders() async throws {
        let (assembler, set) = simulationAssembler(.lateNightProlongedSession)
        let assembled = try await assembler.assemble(manualMood: set.manualMood, isSimulated: true)
        let snapshot = assembled.snapshot
        #expect(snapshot.timestamp == TestSupport.referenceDate)
        #expect(snapshot.sleepDurationHours == 5.0)
        #expect(snapshot.continuousSessionMinutes == 68)
        #expect(snapshot.moodValence == 0.85)
        #expect(snapshot.moodEnergy == 0.15)
        #expect(snapshot.moodSource == .manualCheckIn)
        #expect(snapshot.solarPhase == .night)
        #expect(assembled.report.sleep == .available)
        #expect(assembled.report.interaction == .available)
        // No weather in this scenario: reported, not zero-filled.
        #expect(snapshot.weather == nil)
        #expect(assembled.report.weather == .unavailable)
    }

    // 6. Simulation scenarios: the assembled snapshot drives the engine to
    // the same semantic decision as the scenario's direct snapshot.
    @Test(arguments: [SimulationScenario.lateNightProlongedSession, .recoveryAfterPoorSleep, .highCognitiveLoad])
    func assembledSnapshotDrivesEngineLikeDirectSnapshot(scenario: SimulationScenario) async throws {
        let (assembler, set) = simulationAssembler(scenario)
        let direct = scenario.snapshot(at: TestSupport.referenceDate)
        let assembled = try await assembler.assemble(
            manualMood: set.manualMood,
            focusGoal: direct.focusGoal,
            upcomingInterviewMinutes: direct.upcomingInterviewMinutes,
            accessibility: direct.accessibility,
            isSimulated: true
        )
        func makeEngine() -> TransparentAdaptiveDecisionEngine {
            TransparentAdaptiveDecisionEngine(
                configuration: .unitTest, scoring: .production,
                clock: clock, idGenerator: CountingIDGenerator()
            )
        }
        let fromProviders = await makeEngine().evaluate(
            snapshot: assembled.snapshot, preferences: .default, history: .empty
        )
        let fromDirect = await makeEngine().evaluate(
            snapshot: direct, preferences: .default, history: .empty
        )
        // localHour comes from the fixed UTC calendar rather than the
        // scenario's stylized hour, so compare the semantic decision shape.
        #expect(fromProviders.selectedMode == fromDirect.selectedMode
                || fromProviders.modeScores.first?.mode == fromDirect.modeScores.first?.mode)
    }

    // 2. Missing permissions: typed denial per source, fields stay nil.
    @Test
    func missingPermissionsAreReportedAndFieldsStayMissing() async throws {
        let (assembler, set) = simulationAssembler(.missingPermissions)
        let assembled = try await assembler.assemble(manualMood: set.manualMood, isSimulated: true)
        #expect(assembled.report.sleep == .permissionDenied)
        #expect(assembled.report.stateOfMind == .permissionDenied)
        #expect(assembled.report.activity == .permissionDenied)
        #expect(assembled.snapshot.sleepDurationHours == nil)
        #expect(assembled.snapshot.moodValence == nil)
        #expect(assembled.snapshot.activityLevel == nil)
        let granted = await set.health.requestReadAuthorization()
        #expect(!granted)
    }

    // 3. Stale data: an observation past its maximum age is dropped as
    // missing and reported `.stale` — never silently used.
    @Test
    func staleObservationsAreDroppedAsMissing() async throws {
        let staleWeather = StubWeatherProvider(result: .success(
            WeatherObservation(
                weather: WeatherContext(condition: .clear, temperatureCelsius: 20, isPrecipitating: false, uvIndex: 2),
                observedAt: TestSupport.referenceDate.addingTimeInterval(-3 * 60 * 60)   // 3h > 2h max
            )
        ))
        let set = SimulationProviderSet(scenario: .noNetwork, clock: clock)
        let assembler = ContextSnapshotAssembler(
            weather: staleWeather, health: set.health, ambient: set.ambient,
            interaction: set.interaction, clock: clock
        )
        let assembled = try await assembler.assemble(isSimulated: true)
        #expect(assembled.report.weather == .stale)
        #expect(assembled.snapshot.weather == nil)
    }

    @Test
    func recentObservationInsideTheWindowIsKept() async throws {
        let freshWeather = StubWeatherProvider(result: .success(
            WeatherObservation(
                weather: WeatherContext(condition: .rain, temperatureCelsius: 12, isPrecipitating: true, uvIndex: 0),
                observedAt: TestSupport.referenceDate.addingTimeInterval(-30 * 60)
            )
        ))
        let set = SimulationProviderSet(scenario: .noNetwork, clock: clock)
        let assembler = ContextSnapshotAssembler(
            weather: freshWeather, health: set.health, ambient: set.ambient,
            interaction: set.interaction, clock: clock
        )
        let assembled = try await assembler.assemble(isSimulated: true)
        #expect(assembled.report.weather == .available)
        #expect(assembled.snapshot.weather?.condition == .rain)
    }

    // 4. Partial data: one source failing never blocks the others.
    @Test
    func partialDataStillAssembles() async throws {
        let set = SimulationProviderSet(scenario: .goodSleepProductiveMorning, clock: clock)
        let assembler = ContextSnapshotAssembler(
            weather: StubWeatherProvider(result: .failure(.unavailable)),
            health: set.health, ambient: set.ambient, interaction: set.interaction,
            clock: clock
        )
        let assembled = try await assembler.assemble(manualMood: set.manualMood, isSimulated: true)
        #expect(assembled.report.weather == .unavailable)
        #expect(assembled.snapshot.weather == nil)
        #expect(assembled.snapshot.sleepDurationHours == 8.2)   // health still flowed
        #expect(assembled.report.sleep == .available)
    }

    // 5. Provider failures: even a fully throwing provider set produces a
    // valid, engine-consumable snapshot.
    @Test
    func totalProviderFailureYieldsEmptyButValidSnapshot() async throws {
        let set = SimulationProviderSet(scenario: .noNetwork, clock: clock)
        let assembler = ContextSnapshotAssembler(
            weather: StubWeatherProvider(result: .failure(.networkUnavailable)),
            health: ThrowingHealthProvider(),
            ambient: set.ambient, interaction: set.interaction, clock: clock
        )
        let assembled = try await assembler.assemble(isSimulated: true)
        #expect(assembled.report.weather == .networkUnavailable)
        #expect(assembled.report.sleep == .permissionDenied)
        let engine = TransparentAdaptiveDecisionEngine(
            configuration: .unitTest, scoring: .production,
            clock: clock, idGenerator: CountingIDGenerator()
        )
        let decision = await engine.evaluate(snapshot: assembled.snapshot, preferences: .default, history: .empty)
        #expect(decision.outcome != .applied)   // degraded evidence never auto-applies
    }

    // 9. No-network behavior: network-backed weather reports the typed
    // network error; local sources keep working.
    @Test
    func noNetworkKeepsLocalSourcesWorking() async throws {
        let (assembler, set) = simulationAssembler(.noNetwork)
        let assembled = try await assembler.assemble(manualMood: set.manualMood, isSimulated: true)
        #expect(assembled.report.weather == .networkUnavailable)
        #expect(assembled.snapshot.weather == nil)
        #expect(assembled.snapshot.sleepDurationHours == 7.0)
        #expect(assembled.snapshot.continuousSessionMinutes == 25)
    }

    // 7. Cancellation: propagates out of assembly instead of being
    // swallowed by the per-provider failure isolation.
    @Test
    func cancellationPropagatesFromAssembly() async throws {
        let set = SimulationProviderSet(scenario: .noNetwork, clock: clock)
        let assembler = ContextSnapshotAssembler(
            weather: SlowWeatherProvider(), health: set.health,
            ambient: set.ambient, interaction: set.interaction, clock: clock
        )
        let task = Task {
            try await assembler.assemble(isSimulated: true)
        }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        let result = await task.result
        switch result {
        case .success:
            Issue.record("Assembly should have been cancelled")
        case .failure(let error):
            #expect(error is CancellationError)
        }
    }

    // 8. Deterministic timestamps: identical clock → identical snapshot
    // timestamps and identical engine fingerprints across assemblies.
    @Test
    func deterministicTimestampsAcrossAssemblies() async throws {
        let (assembler, set) = simulationAssembler(.lateNightProlongedSession)
        let first = try await assembler.assemble(manualMood: set.manualMood, isSimulated: true)
        let second = try await assembler.assemble(manualMood: set.manualMood, isSimulated: true)
        #expect(first.snapshot.timestamp == second.snapshot.timestamp)
        #expect(first.report == second.report)
        func makeEngine() -> TransparentAdaptiveDecisionEngine {
            TransparentAdaptiveDecisionEngine(
                configuration: .unitTest, scoring: .production,
                clock: clock, idGenerator: CountingIDGenerator()
            )
        }
        let d1 = await makeEngine().evaluate(snapshot: first.snapshot, preferences: .default, history: .empty)
        let d2 = await makeEngine().evaluate(snapshot: second.snapshot, preferences: .default, history: .empty)
        #expect(AdaptationDecisionFingerprint(decision: d1) == AdaptationDecisionFingerprint(decision: d2))
    }

    // 6b. Every scenario assembles without throwing (degradation included).
    @Test
    func allScenariosAssembleWithoutThrowing() async throws {
        for scenario in SimulationScenario.allCases {
            let (assembler, set) = simulationAssembler(scenario)
            let assembled = try await assembler.assemble(manualMood: set.manualMood, isSimulated: true)
            #expect(assembled.snapshot.isSimulated)
        }
    }

    // Manual check-in outranks HealthKit State of Mind (B.7 rule 2).
    @Test
    func manualMoodOutranksHealthKitStateOfMind() async throws {
        struct MindHealthProvider: HealthDataProviding {
            let clock: any AdaptiveClock
            var isAvailable: Bool { true }
            func requestReadAuthorization() async -> Bool { true }
            func recentSleep() async throws -> SleepObservation { throw ProviderError.unavailable }
            func recentStateOfMind() async throws -> MoodObservation {
                MoodObservation(mood: .low, valence: 0.3, energy: 0.4, source: .healthKitStateOfMind, observedAt: clock.now)
            }
            func todayActivity() async throws -> ActivityObservation { throw ProviderError.unavailable }
        }
        let set = SimulationProviderSet(scenario: .noNetwork, clock: clock)
        let assembler = ContextSnapshotAssembler(
            weather: StubWeatherProvider(result: .failure(.unavailable)),
            health: MindHealthProvider(clock: clock),
            ambient: set.ambient, interaction: set.interaction, clock: clock
        )
        let manual = MoodObservation(mood: .positive, valence: 0.8, energy: 0.7, source: .manualCheckIn, observedAt: clock.now)
        let withManual = try await assembler.assemble(manualMood: manual, isSimulated: true)
        #expect(withManual.snapshot.moodSource == .manualCheckIn)
        #expect(withManual.snapshot.moodValence == 0.8)
        let withoutManual = try await assembler.assemble(isSimulated: true)
        #expect(withoutManual.snapshot.moodSource == .healthKitStateOfMind)
        #expect(withoutManual.snapshot.moodValence == 0.3)
    }

    // Notification provider contract: schedule/replace/cancel, denial throws.
    @Test
    func notificationProviderSchedulesReplacesAndCancels() async throws {
        let provider = SimulationNotificationProvider(authorizationGranted: true)
        try await provider.schedule(ScheduledReminder(
            kind: .takeBreak, fireAfter: 20 * 60, title: "Short break?", body: "You have been at this a while."
        ))
        try await provider.schedule(ScheduledReminder(
            kind: .takeBreak, fireAfter: 30 * 60, title: "Short break?", body: "Replaced."
        ))
        var scheduled = await provider.scheduled
        #expect(scheduled.count == 1)
        #expect(scheduled[.takeBreak]?.fireAfter == 30 * 60)
        await provider.cancelReminder(kind: .takeBreak)
        scheduled = await provider.scheduled
        #expect(scheduled.isEmpty)

        let denied = SimulationNotificationProvider(authorizationGranted: false)
        await #expect(throws: ProviderError.permissionDenied) {
            try await denied.schedule(ScheduledReminder(kind: .moodCheckIn, fireAfter: 60, title: "t", body: "b"))
        }
    }
}
