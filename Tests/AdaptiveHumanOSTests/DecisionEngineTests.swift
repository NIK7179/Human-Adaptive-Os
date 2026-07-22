import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Section B.24 engine coverage, items 1–20 (plus fingerprint determinism).
struct DecisionEngineTests {
    private func makeEngine(
        configuration: AdaptiveEngineConfiguration = .unitTest
    ) -> TransparentAdaptiveDecisionEngine {
        TransparentAdaptiveDecisionEngine(
            configuration: configuration,
            scoring: .production,
            clock: TestSupport.clock,
            idGenerator: CountingIDGenerator()
        )
    }

    private var lateNightSnapshot: ContextSnapshot {
        SimulationScenario.lateNightProlongedSession.snapshot(at: TestSupport.referenceDate)
    }

    // 1. Same input → same output (semantic fingerprint equality).
    @Test
    func identicalInputsProduceIdenticalSemanticOutput() async {
        let first = await makeEngine().evaluate(
            snapshot: lateNightSnapshot, preferences: .default, history: .empty
        )
        let second = await makeEngine().evaluate(
            snapshot: lateNightSnapshot, preferences: .default, history: .empty
        )
        #expect(AdaptationDecisionFingerprint(decision: first) == AdaptationDecisionFingerprint(decision: second))
    }

    // 2. Signal processing order does not affect scores: contribution sums
    // and reliability aggregation are order-invariant because the engine
    // sorts votes deterministically before accumulation.
    @Test
    func voteOrderDoesNotAffectDerivedCounts() {
        let votes = TestSupport.eyeComfortFixtureVotes()
        let analyzer = SignalContributionAnalyzer()
        let forward = analyzer.independentContributingSignalCount(winnerVotes: votes)
        let backward = analyzer.independentContributingSignalCount(winnerVotes: votes.reversed())
        #expect(forward == backward)
        let calc = ContributionWeightedReliabilityCalculator(contributionEpsilon: 0.0001)
        let forwardReliability = calc.calculate(votes: analyzer.reliabilityInputs(winnerVotes: votes))
        let backwardReliability = calc.calculate(
            votes: analyzer.reliabilityInputs(winnerVotes: votes.reversed())
        )
        // Same five values in reversed accumulation order — equal within the
        // fixture tolerance (see A.11 policy).
        #expect(abs((forwardReliability ?? -1) - (backwardReliability ?? -2)) < 1e-12)
    }

    // 3. Expired signals are ignored.
    @Test
    func expiredSignalsDoNotContribute() {
        let expired = ContextSignal(
            id: TestSupport.uuid(50), kind: .prolongedSession, normalizedValue: 0.9,
            reliability: 0.9, source: .interactionHistory,
            timestamp: TestSupport.referenceDate.addingTimeInterval(-7200),
            expiresAt: TestSupport.referenceDate.addingTimeInterval(-3600),
            isApproximation: false, explanation: "Old session."
        )
        #expect(!expired.isValid(at: TestSupport.referenceDate))
        let fresh = ContextSignal(
            id: TestSupport.uuid(51), kind: .prolongedSession, normalizedValue: 0.9,
            reliability: 0.9, source: .interactionHistory,
            timestamp: TestSupport.referenceDate, expiresAt: nil,
            isApproximation: false, explanation: "Current session."
        )
        #expect(fresh.isValid(at: TestSupport.referenceDate))
    }

    // 4. Missing signals stay missing — a snapshot without sleep data
    // generates neither poorSleep nor goodSleep (never zero-valued signals).
    @Test
    func missingSleepDataGeneratesNoSleepSignal() async {
        let snapshot = ContextSnapshot(
            timestamp: TestSupport.referenceDate, localHour: 13, dayOfWeek: 3, solarPhase: .afternoon,
            isSimulated: true
        )
        let generator = ContextSignalGenerator(configuration: .production, idGenerator: CountingIDGenerator())
        let signals = await generator.signals(from: snapshot)
        #expect(!signals.contains { $0.kind == .poorSleep || $0.kind == .goodSleep })
        #expect(!signals.contains { $0.kind == .lowEnergy || $0.kind == .highEnergy })
    }

    // 5. Poor sleep votes Recovery.
    @Test
    func poorSleepVotesForRecovery() async {
        let snapshot = SimulationScenario.recoveryAfterPoorSleep.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        let recovery = decision.modeScores.first { $0.mode == .recovery }
        #expect(recovery != nil)
        #expect(recovery?.positiveContributors.contains { $0.signalKind == .poorSleep } == true)
        #expect(decision.modeScores.first?.mode == .recovery)
    }

    // 6. Late-night fatigue votes Eye Comfort (the worked example).
    @Test
    func lateNightFatigueRanksEyeComfortFirstAndSuggests() async {
        let decision = await makeEngine().evaluate(
            snapshot: lateNightSnapshot, preferences: .default, history: .empty
        )
        #expect(decision.modeScores.first?.mode == .eyeComfort)
        #expect(decision.selectedMode == .eyeComfort)
        #expect(decision.outcome == .suggested)
        #expect(decision.confidence.conflictingSignalCount >= 1)
    }

    // 7. High outdoor visibility votes Outdoor Visibility.
    @Test
    func brightOutdoorContextSelectsOutdoorVisibility() async {
        let snapshot = SimulationScenario.sunnyOutdoorAfternoon.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        #expect(decision.modeScores.first?.mode == .outdoorVisibility)
        #expect(decision.selectedMode == .outdoorVisibility)
        #expect(decision.outcome == .applied || decision.outcome == .suggested)
    }

    // 8. Explicit interview goal outranks inferred calm pressure.
    @Test
    func explicitInterviewOutweighsInferredCalm() async {
        let snapshot = SimulationScenario.interviewInOneHour.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        #expect(decision.modeScores.first?.mode == .interviewPreparation)
    }

    // 9. Accessibility modifiers apply to every mode.
    @Test
    func accessibilityConstraintsApplyRegardlessOfMode() async {
        let accessibility = AccessibilityContext(
            reduceMotionEnabled: true, increaseContrastEnabled: true,
            largerTextEnabled: true, reduceTransparencyEnabled: true
        )
        for scenario in [SimulationScenario.goodSleepProductiveMorning, .sunnyOutdoorAfternoon] {
            let base = scenario.snapshot(at: TestSupport.referenceDate)
            let snapshot = ContextSnapshot(
                timestamp: base.timestamp, localHour: base.localHour, dayOfWeek: base.dayOfWeek,
                solarPhase: base.solarPhase, weather: base.weather, likelyOutdoors: base.likelyOutdoors,
                ambientLight: base.ambientLight, mood: base.mood, moodValence: base.moodValence,
                moodEnergy: base.moodEnergy, moodSource: base.moodSource,
                moodReportedAt: base.moodReportedAt, sleepDurationHours: base.sleepDurationHours,
                sleepQuality: base.sleepQuality, activityLevel: base.activityLevel,
                accessibility: accessibility, isSimulated: true
            )
            let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
            #expect(decision.theme.motion <= .minimal)
            #expect(decision.theme.contrast >= .elevated)
            #expect(decision.theme.usesTranslucentMaterials == false)
            #expect(decision.modifiers.reduceMotion)
            #expect(decision.modifiers.increaseContrast)
            #expect(decision.modifiers.increaseTextScale)
        }
    }

    // 10. Low Power Mode reduces motion without hijacking the primary mode.
    @Test
    func lowPowerModeShapesModifiersNotPrimaryMode() async {
        let base = SimulationScenario.goodSleepProductiveMorning.snapshot(at: TestSupport.referenceDate)
        let snapshot = ContextSnapshot(
            timestamp: base.timestamp, localHour: base.localHour, dayOfWeek: base.dayOfWeek,
            solarPhase: base.solarPhase, weather: base.weather, likelyOutdoors: base.likelyOutdoors,
            ambientLight: base.ambientLight, mood: base.mood, moodValence: base.moodValence,
            moodEnergy: base.moodEnergy, moodSource: base.moodSource,
            moodReportedAt: base.moodReportedAt, sleepDurationHours: base.sleepDurationHours,
            sleepQuality: base.sleepQuality, activityLevel: base.activityLevel,
            power: PowerContext(isLowPowerModeEnabled: true, thermalPressure: .nominal),
            isSimulated: true
        )
        let withPower = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        let without = await makeEngine().evaluate(snapshot: base, preferences: .default, history: .empty)
        #expect(withPower.modeScores.first?.mode == without.modeScores.first?.mode)
        #expect(withPower.modifiers.reduceMotion)
        #expect(withPower.modifiers.reduceVisualComplexity)
    }

    // 11. Thermal pressure applies low-complexity modifiers and slows
    // reevaluation instead of speeding it up.
    @Test
    func thermalPressureAppliesLowComplexityModifiers() async {
        let base = SimulationScenario.highCognitiveLoad.snapshot(at: TestSupport.referenceDate)
        let snapshot = ContextSnapshot(
            timestamp: base.timestamp, localHour: base.localHour, dayOfWeek: base.dayOfWeek,
            solarPhase: base.solarPhase, continuousSessionMinutes: base.continuousSessionMinutes,
            rapidNavigationRate: base.rapidNavigationRate,
            minutesSinceLastBreak: base.minutesSinceLastBreak, focusGoal: base.focusGoal,
            power: PowerContext(isLowPowerModeEnabled: false, thermalPressure: .serious),
            isSimulated: true
        )
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        #expect(decision.modifiers.reduceVisualComplexity)
        #expect(decision.modifiers.reduceMotion)
        #expect(decision.theme.motion <= .minimal)
        #expect(decision.theme.complexity <= .reduced)
        #expect(decision.reevaluateAfter > AdaptiveEngineConfiguration.unitTest.defaultReevaluationInterval)
    }

    // 12. Weak evidence stays in the current mode (Balanced).
    @Test
    func weakEvidenceLeavesBalancedUnchanged() async {
        let snapshot = ContextSnapshot(
            timestamp: TestSupport.referenceDate, localHour: 13, dayOfWeek: 3,
            solarPhase: .afternoon, isSimulated: true
        )
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        #expect(decision.selectedMode == .balanced)
        #expect(decision.outcome != .applied)
    }

    // 13. Low confidence → no adaptation, with the required explanation.
    @Test
    func lowConfidenceProducesUnchangedOutcomeWithExplanation() async {
        let snapshot = SimulationScenario.missingPermissions.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        #expect(decision.outcome == .unchangedLowConfidence
                || decision.outcome == .unchangedInsufficientDifference)
        #expect(decision.selectedMode == .balanced)
        #expect(!decision.explanation.summary.isEmpty)
    }

    // 14. Medium confidence → suggestion (the keystone path, via the engine).
    @Test
    func mediumConfidenceYieldsSuggestionNotSilentSwitch() async {
        let decision = await makeEngine().evaluate(
            snapshot: lateNightSnapshot, preferences: .default, history: .empty
        )
        #expect(decision.outcome == .suggested)
        #expect(decision.confidence.overall >= 0.60)
        #expect(decision.confidence.overall <= 0.72)
    }

    // 15. High confidence → automatic application.
    @Test
    func highConfidenceAppliesAutomatically() async {
        let snapshot = SimulationScenario.sunnyOutdoorAfternoon.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        #expect(decision.outcome == .applied)
        #expect(decision.confidence.overall > 0.72)
    }

    // 16. Small margins are rejected by hysteresis.
    @Test
    func smallMarginRejectedByHysteresis() async {
        // Current mode is already eyeComfort's closest competitor: force the
        // current mode score high by starting IN recovery for a
        // recovery-leaning snapshot, then check a near-tie does not switch.
        let snapshot = SimulationScenario.recoveryAfterPoorSleep.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(
            snapshot: snapshot,
            preferences: .default,
            history: AdaptationHistory(currentMode: .calm)
        )
        if decision.outcome == .applied || decision.outcome == .suggested {
            // If it did move, the margin must have cleared hysteresis.
            let winner = decision.modeScores.first { $0.mode == decision.selectedMode }
            let current = decision.modeScores.first { $0.mode == .calm }
            let margin = (winner?.normalizedScore ?? 0) - (current?.normalizedScore ?? 0)
            #expect(margin >= AdaptiveEngineConfiguration.unitTest.normalHysteresis - 1e-9)
        } else {
            #expect(decision.selectedMode == .calm)
        }
    }

    // 17. Cooldown prevents rapid automatic switching.
    @Test
    func cooldownBlocksBackToBackAutomaticChanges() async {
        let history = AdaptationHistory(
            currentMode: .energize,
            lastAutomaticChangeAt: TestSupport.referenceDate.addingTimeInterval(-5 * 60),
            lastAutomaticChangeMode: .energize
        )
        // Strong non-visibility candidate: interview prep.
        let snapshot = SimulationScenario.interviewInOneHour.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: history)
        #expect(decision.outcome != .applied)
        if decision.outcome == .unchangedCooldown {
            #expect(decision.selectedMode == .energize)
        }
    }

    // 18. Manual overrides block automatic replacement.
    @Test
    func manualOverrideBlocksAutomaticReplacement() async {
        let scenario = SimulationScenario.manualModeOverride
        let snapshot = scenario.snapshot(at: TestSupport.referenceDate)
        let override = scenario.manualOverride(at: TestSupport.referenceDate)
        #expect(override != nil)
        let history = AdaptationHistory(currentMode: .calm, activeOverride: override,
                                        lastOverrideStartedAt: override?.startedAt)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: history)
        #expect(decision.outcome == .blockedByManualOverride)
        #expect(decision.selectedMode == .calm)
        // The engine still evaluated context underneath.
        #expect(decision.modeScores.first?.mode == .outdoorVisibility)
    }

    // 19. Critical visibility bypasses cooldown.
    @Test
    func outdoorVisibilityBypassesCooldown() async {
        let history = AdaptationHistory(
            currentMode: .balanced,
            lastAutomaticChangeAt: TestSupport.referenceDate.addingTimeInterval(-2 * 60),
            lastAutomaticChangeMode: .balanced
        )
        let snapshot = SimulationScenario.sunnyOutdoorAfternoon.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: history)
        #expect(decision.outcome == .applied)
        #expect(decision.selectedMode == .outdoorVisibility)
    }

    // 20. Explicit mood outweighs an interaction estimate: the estimate is
    // marked as an approximation with strictly lower reliability.
    @Test
    func explicitMoodCarriesMoreReliabilityThanInteractionEstimate() async {
        func snapshot(source: MoodSource) -> ContextSnapshot {
            ContextSnapshot(
                timestamp: TestSupport.referenceDate, localHour: 19, dayOfWeek: 4,
                solarPhase: .civilTwilightEvening, moodValence: 0.2, moodEnergy: 0.3,
                moodSource: source, isSimulated: true
            )
        }
        let generator = ContextSignalGenerator(configuration: .production, idGenerator: CountingIDGenerator())
        let explicitSignals = await generator.signals(from: snapshot(source: .manualCheckIn))
        let inferredSignals = await generator.signals(from: snapshot(source: .interactionEstimate))
        let explicitValence = explicitSignals.first { $0.kind == .negativeValence }
        let inferredValence = inferredSignals.first { $0.kind == .negativeValence }
        #expect(explicitValence != nil)
        #expect(inferredValence != nil)
        #expect((explicitValence?.reliability ?? 0) > (inferredValence?.reliability ?? 1))
        #expect(inferredValence?.isApproximation == true)
        #expect(explicitValence?.isApproximation == false)
    }

    // 26. Every adaptation includes a validated explanation.
    @Test
    func decisionsAlwaysCarryValidExplanations() async throws {
        for scenario in SimulationScenario.allCases {
            let snapshot = scenario.snapshot(at: TestSupport.referenceDate)
            let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
            try validateExplanation(for: decision)
        }
    }

    // 35. No prohibited diagnostic language in generated explanations.
    @Test
    func generatedExplanationsAvoidDiagnosticLanguage() async {
        for scenario in SimulationScenario.allCases {
            let snapshot = scenario.snapshot(at: TestSupport.referenceDate)
            let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: .default, history: .empty)
            let text = (decision.explanation.headline + " " + decision.explanation.summary).lowercased()
            for term in ExplanationValidator.prohibitedTerms {
                #expect(!text.contains(term))
            }
        }
    }

    // Stable ordering: mode scores are sorted by the documented rule.
    @Test
    func modeScoresUseStableDocumentedOrdering() async {
        let decision = await makeEngine().evaluate(
            snapshot: lateNightSnapshot, preferences: .default, history: .empty
        )
        let scores = decision.modeScores
        for index in 1..<scores.count {
            let previous = scores[index - 1]
            let current = scores[index]
            let orderedCorrectly = previous.normalizedScore > current.normalizedScore
                || (previous.normalizedScore == current.normalizedScore
                    && previous.rawScore > current.rawScore)
                || (previous.normalizedScore == current.normalizedScore
                    && previous.rawScore == current.rawScore
                    && previous.mode.rawValue <= current.mode.rawValue)
            #expect(orderedCorrectly)
        }
    }

    // Disabled modes are excluded and marked with a reason.
    @Test
    func disabledModesAreExcludedFromSelection() async {
        var preferences = AdaptivePreferences.default
        preferences.disabledModes = [.eyeComfort]
        let decision = await makeEngine().evaluate(
            snapshot: lateNightSnapshot, preferences: preferences, history: .empty
        )
        #expect(decision.selectedMode != .eyeComfort)
        let excluded = decision.modeScores.first { $0.mode == .eyeComfort }
        #expect(excluded?.isEligible == false)
        #expect(excluded?.exclusionReasons.isEmpty == false)
    }

    // Automatic adaptation disabled → high confidence downgrades to suggestion.
    @Test
    func automaticDisabledDowngradesToSuggestion() async {
        var preferences = AdaptivePreferences.default
        preferences.automaticAdaptationEnabled = false
        let snapshot = SimulationScenario.sunnyOutdoorAfternoon.snapshot(at: TestSupport.referenceDate)
        let decision = await makeEngine().evaluate(snapshot: snapshot, preferences: preferences, history: .empty)
        #expect(decision.outcome == .suggested)
    }
}
