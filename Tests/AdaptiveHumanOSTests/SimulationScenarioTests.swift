import Testing
import Foundation
@testable import AdaptiveHumanOS

/// B.24 item 34: simulation scenarios produce the expected ranked
/// candidates; degradation scenarios degrade gracefully.
struct SimulationScenarioTests {
    private func makeEngine() -> TransparentAdaptiveDecisionEngine {
        TransparentAdaptiveDecisionEngine(
            configuration: .unitTest, scoring: .production,
            clock: TestSupport.clock, idGenerator: CountingIDGenerator()
        )
    }

    @Test(arguments: SimulationScenario.allCases.filter { $0.expectedLeader != nil })
    func scenarioProducesExpectedLeader(scenario: SimulationScenario) async {
        let snapshot = scenario.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        #expect(decision.modeScores.first?.mode == scenario.expectedLeader)
    }

    @Test
    func allScenariosMarkTheirDataAsSimulated() async {
        for scenario in SimulationScenario.allCases {
            let snapshot = scenario.snapshot(at: TestSupport.referenceDate)
            #expect(snapshot.isSimulated)
            let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
            // Every used source must be reported as simulation.
            #expect(decision.explanation.dataSourcesUsed.allSatisfy { $0 == .simulation })
        }
    }

    @Test
    func missingPermissionsScenarioDegradesGracefully() async {
        let snapshot = SimulationScenario.missingPermissions.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        #expect(decision.outcome == .unchangedLowConfidence
                || decision.outcome == .unchangedInsufficientDifference)
        // Unavailability is surfaced, not hidden.
        #expect(!decision.explanation.unavailableSignals.isEmpty)
    }

    @Test
    func noNetworkScenarioStillEvaluatesLocalSignals() async {
        let snapshot = SimulationScenario.noNetwork.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        // Weather is absent, but sleep and session data still produce votes.
        #expect(decision.explanation.unavailableSignals.contains { $0.name == "Weather" })
        #expect(decision.modeScores.contains { !$0.positiveContributors.isEmpty })
    }

    @Test
    func lateNightScenarioMatchesWorkedExampleShape() async {
        // The engine-level analogue of the keystone: same snapshot as the
        // B.6A worked example must produce an Eye Comfort suggestion with
        // exactly one conflicting and five independent signals.
        let snapshot = SimulationScenario.lateNightProlongedSession.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        #expect(decision.selectedMode == .eyeComfort)
        #expect(decision.outcome == .suggested)
        #expect(decision.confidence.independentSignalCount == 5)
        #expect(decision.confidence.conflictingSignalCount == 1)
        #expect(abs(decision.confidence.conflictPenalty - 0.92) < 1e-6)
    }

    @Test
    func solarPhasesCoverPolarCasesWithoutFabricatingSunEvents() async {
        // Polar night: late-night signal generated, explanation says so.
        let polarNight = ContextSnapshot(
            timestamp: TestSupport.referenceDate, localHour: 23, dayOfWeek: 2,
            solarPhase: .polarNight, isSimulated: true
        )
        let generator = ContextSignalGenerator(configuration: .production, idGenerator: CountingIDGenerator())
        let nightSignals = await generator.signals(from: polarNight)
        let lateNight = nightSignals.first { $0.kind == .lateNight }
        #expect(lateNight != nil)
        #expect(lateNight?.explanation.contains("polar night") == true)
        // Polar day at the same hour: no late-night signal, a daytime signal.
        let polarDay = ContextSnapshot(
            timestamp: TestSupport.referenceDate, localHour: 23, dayOfWeek: 2,
            solarPhase: .polarDay, isSimulated: true
        )
        let daySignals = await generator.signals(from: polarDay)
        #expect(!daySignals.contains { $0.kind == .lateNight })
        #expect(daySignals.contains { $0.kind == .daytime })
        // Unavailable solar model: clearly-identified approximation.
        let unavailable = ContextSnapshot(
            timestamp: TestSupport.referenceDate, localHour: 23, dayOfWeek: 2,
            solarPhase: .unavailable, isSimulated: true
        )
        let approxSignals = await generator.signals(from: unavailable)
        let approx = approxSignals.first { $0.kind == .lateNight }
        #expect(approx?.isApproximation == true)
    }
}
