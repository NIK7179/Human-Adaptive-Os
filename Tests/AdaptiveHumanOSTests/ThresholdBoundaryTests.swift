import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Section A.10 — outcome thresholds: `< 0.60` unchanged, `0.60...0.72`
/// suggested (both edges inclusive), `> 0.72` applied.
struct ThresholdBoundaryTests {
    private let selector = AdaptationOutcomeSelector(configuration: .production)

    @Test
    func justBelowSuggestionThresholdRemainsUnchanged() {
        #expect(selector.outcome(for: 0.5999999) == .unchangedLowConfidence)
    }

    @Test
    func exactlyAtSuggestionThresholdSuggests() {
        #expect(selector.outcome(for: 0.60) == .suggested)
    }

    @Test
    func betweenThresholdsSuggests() {
        #expect(selector.outcome(for: 0.66) == .suggested)
    }

    @Test
    func exactlyAtAutomaticThresholdStillOnlySuggests() {
        #expect(selector.outcome(for: 0.72) == .suggested)
    }

    @Test
    func justAboveAutomaticThresholdApplies() {
        #expect(selector.outcome(for: 0.7200001) == .applied)
    }

    @Test
    func extremesMapToExpectedOutcomes() {
        #expect(selector.outcome(for: 0.0) == .unchangedLowConfidence)
        #expect(selector.outcome(for: 1.0) == .applied)
    }

    @Test
    func conflictPenaltyNeverDropsBelowConfiguredMinimum() {
        let calculator = ConfidenceCalculator(configuration: .production)
        // Every independent signal conflicts: ratio 1.0 → raw penalty 0.60,
        // still above the 0.55 floor; ratio beyond 1 is impossible, so also
        // verify the floor engages with a hostile configuration.
        let confidence = calculator.calculate(
            input: ConfidenceInput(
                winningScore: 0.9,
                runnerUpScore: 0.1,
                averageReliability: 1.0,
                independentSignalCount: 2,
                conflictingSignalCount: 2,
                freshnessFactor: 1.0,
                explicitInputFactor: 1.0
            )
        )
        #expect(confidence.conflictPenalty >= 0.55)
        #expect(abs(confidence.conflictPenalty - 0.60) < 1e-12)

        let harsh = ConfidenceConfiguration(
            winningScoreWeight: 0.30, scoreMarginWeight: 0.25, reliabilityWeight: 0.20,
            independentSignalsWeight: 0.10, freshnessWeight: 0.10, explicitInputWeight: 0.05,
            targetDecisiveMargin: 0.25, targetIndependentSignalCount: 4,
            conflictPenaltyStrength: 0.90, minimumConflictPenalty: 0.55,
            suggestionThreshold: 0.60, automaticThreshold: 0.72
        )
        let floored = ConfidenceCalculator(configuration: harsh).calculate(
            input: ConfidenceInput(
                winningScore: 0.9, runnerUpScore: 0.1, averageReliability: 1.0,
                independentSignalCount: 2, conflictingSignalCount: 2,
                freshnessFactor: 1.0, explicitInputFactor: 1.0
            )
        )
        #expect(abs(floored.conflictPenalty - 0.55) < 1e-12)
    }

    @Test
    func overallConfidenceIsClampedToUnitInterval() {
        let confidence = ConfidenceCalculator(configuration: .production).calculate(
            input: ConfidenceInput(
                winningScore: 5.0, runnerUpScore: -3.0, averageReliability: 7.0,
                independentSignalCount: 100, conflictingSignalCount: 0,
                freshnessFactor: 9.0, explicitInputFactor: 9.0
            )
        )
        #expect(confidence.overall <= 1.0)
        #expect(confidence.overall >= 0.0)
        #expect(confidence.winningScore == 1.0)
        #expect(confidence.independentSignalFactor == 1.0)
    }
}
