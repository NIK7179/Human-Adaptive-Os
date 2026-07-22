import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Comfort score renormalization and missing-factor safeguards
/// (Sections B.16 / B.16A).
struct ComfortScoreTests {
    private let calculator = ComfortScoreCalculator()

    private func factor(
        _ kind: ComfortFactorKind, value: Double, observations: Int = 6
    ) -> ComfortFactorInput {
        ComfortFactorInput(kind: kind, value: value, observationCount: observations)
    }

    // 22. Missing factors renormalize proportionally, never substitute zero.
    @Test
    func missingFactorsRenormalizeProportionally() throws {
        // Only three factors available (weights 0.20 + 0.15 + 0.15 = 0.50),
        // all with value 1.0 → renormalized score must be 100, not 50.
        let result = calculator.calculate(factors: [
            factor(.currentModeHistoricalEffectiveness, value: 1.0),
            factor(.visualAccessibilityAlignment, value: 1.0),
            factor(.sessionFatigueAlignment, value: 1.0),
        ])
        #expect(result.score == 100)
        #expect(result.missingFactors.count == 3)
        // Renormalized weights must be capped at 0.45 (0.20/0.50 = 0.40 OK).
        for contributing in result.contributingFactors {
            #expect(contributing.weight <= 0.45 + 1e-9)
        }
    }

    // 23. Insufficient data returns unavailable, not a fabricated number.
    @Test
    func fewerThanThreeFactorsYieldsNoScore() {
        let result = calculator.calculate(factors: [
            factor(.explicitRecentFeedback, value: 0.9),
            factor(.currentModeHistoricalEffectiveness, value: 0.8),
        ])
        #expect(result.score == nil)
    }

    @Test
    func insufficientWeightCoverageYieldsNoScore() {
        // Three light factors: 0.15 + 0.15 + 0.10 = 0.40 < 0.50 coverage.
        let result = calculator.calculate(factors: [
            factor(.visualAccessibilityAlignment, value: 0.9),
            factor(.sessionFatigueAlignment, value: 0.9),
            factor(.environmentalVisibilityAlignment, value: 0.9),
        ])
        #expect(result.score == nil)
    }

    @Test
    func renormalizedShareIsCappedAtMaximum() throws {
        // explicitRecentFeedback (0.30) + two light factors (0.15, 0.10) =
        // 0.55 coverage → naive share 0.545 exceeds 0.45 and must be capped.
        let result = calculator.calculate(factors: [
            factor(.explicitRecentFeedback, value: 1.0),
            factor(.sessionFatigueAlignment, value: 0.5),
            factor(.userPreferenceAlignment, value: 0.5),
        ])
        let feedback = result.contributingFactors.first {
            $0.name == ComfortFactorKind.explicitRecentFeedback.displayName
        }
        let weight = try #require(feedback?.weight)
        #expect(weight <= 0.45 + 1e-9)
        // Weights still sum to 1 after redistribution.
        let total = result.contributingFactors.reduce(0.0) { $0 + $1.weight }
        #expect(abs(total - 1.0) < 1e-9)
    }

    @Test
    func lowObservationCountsSuppressTheNumericScore() {
        // All factors present but each backed by a single observation →
        // reliability caps at 0.35 everywhere → numeric score suppressed.
        let result = calculator.calculate(
            factors: ComfortFactorKind.allCases.map {
                ComfortFactorInput(kind: $0, value: 0.8, observationCount: 1)
            }
        )
        #expect(result.score == nil)
        #expect(result.confidence > 0.0)
    }

    @Test
    func reliabilityCapsFollowConfiguredLadder() {
        #expect(calculator.reliabilityCap(observationCount: 0) == 0.0)
        #expect(calculator.reliabilityCap(observationCount: 1) == 0.35)
        #expect(calculator.reliabilityCap(observationCount: 2) == 0.55)
        #expect(calculator.reliabilityCap(observationCount: 3) == 0.75)
        #expect(calculator.reliabilityCap(observationCount: 5) == 1.00)
    }

    @Test
    func fullDataProducesBoundedScoreAndConfidence() throws {
        let result = calculator.calculate(
            factors: ComfortFactorKind.allCases.map {
                ComfortFactorInput(kind: $0, value: 0.7, observationCount: 6)
            }
        )
        let score = try #require(result.score)
        #expect(score == 70)
        #expect(result.confidence > 0.8)
        #expect(result.missingFactors.isEmpty)
    }
}
