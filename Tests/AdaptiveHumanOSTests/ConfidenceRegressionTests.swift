import Testing
import Foundation
@testable import AdaptiveHumanOS

/// THE KEYSTONE (Section A.9). This is the executable specification for the
/// scoring + confidence pipeline. It exercises the production
/// `ContributionWeightedReliabilityCalculator`, `LogisticScoreNormalizer`,
/// `ConfidenceCalculator` and `AdaptationOutcomeSelector` — no test-local
/// copies of any formula.
///
/// Constant provenance: `averageReliability = 0.9445876032235598` is
/// `1.89881 / 2.0102` computed without intermediate rounding;
/// `overall = 0.6833730781418192` follows from the full-precision chain.
/// If a deliberate configuration change alters these, update both the test
/// constants and the hand-worked calculation in the same commit.
struct ConfidenceRegressionTests {
    @Test
    func lateNightEyeComfortFixtureProducesSuggestion() throws {
        let contributions: [ReliabilityVoteInput] = [
            .init(contribution:  0.7374, reliability: 0.95),
            .init(contribution:  0.4752, reliability: 0.90),
            .init(contribution:  0.4016, reliability: 1.00),
            .init(contribution:  0.2700, reliability: 0.90),
            .init(contribution: -0.1260, reliability: 1.00)
        ]
        let reliabilityCalculator = ContributionWeightedReliabilityCalculator(contributionEpsilon: 0.0001)
        let averageReliability = try #require(reliabilityCalculator.calculate(votes: contributions))
        let normalizer = LogisticScoreNormalizer(temperature: 1.0)
        let winningScore = normalizer.normalize(rawScore: 1.7582)
        let calculator = ConfidenceCalculator(configuration: .production)
        let confidence = calculator.calculate(
            input: ConfidenceInput(
                winningScore: winningScore,
                runnerUpScore: 0.791,          // injected fixture input
                averageReliability: averageReliability,
                independentSignalCount: 5,      // handed in here; derived in a separate test
                conflictingSignalCount: 1,      // handed in here; derived in a separate test
                freshnessFactor: 0.96,          // injected fixture input
                explicitInputFactor: 0.80       // explicit check-in present, no manual override
            )
        )
        let selector = AdaptationOutcomeSelector(configuration: .production)
        let outcome = selector.outcome(for: confidence.overall)

        // Corrected full-precision constants (verified by hand calculation):
        let confidenceTolerance = 1e-6
        #expect(abs(averageReliability - 0.9445876032235598) < confidenceTolerance)
        #expect(abs(winningScore - 0.852984) < confidenceTolerance)
        #expect(abs(confidence.normalizedScoreMargin - 0.247936) < confidenceTolerance)
        #expect(confidence.independentSignalCount == 5)
        #expect(confidence.conflictingSignalCount == 1)
        #expect(abs(confidence.conflictPenalty - 0.92) < confidenceTolerance)
        #expect(abs(confidence.overall - 0.6833730781418192) < confidenceTolerance)
        #expect(outcome == .suggested)
    }

    /// Section B.6A automatic-adaptation variation: hold the conflict
    /// penalty's inputs constant and change only the runner-up (0.690) so the
    /// margin effect alone lifts confidence above the automatic threshold.
    @Test
    func widerMarginVariationBecomesEligibleForAutomaticApplication() throws {
        let contributions: [ReliabilityVoteInput] = [
            .init(contribution:  0.7374, reliability: 0.95),
            .init(contribution:  0.4752, reliability: 0.90),
            .init(contribution:  0.4016, reliability: 1.00),
            .init(contribution:  0.2700, reliability: 0.90),
            .init(contribution: -0.1260, reliability: 1.00)
        ]
        let reliabilityCalculator = ContributionWeightedReliabilityCalculator(contributionEpsilon: 0.0001)
        let averageReliability = try #require(reliabilityCalculator.calculate(votes: contributions))
        let winningScore = LogisticScoreNormalizer(temperature: 1.0).normalize(rawScore: 1.7582)
        let confidence = ConfidenceCalculator(configuration: .production).calculate(
            input: ConfidenceInput(
                winningScore: winningScore,
                runnerUpScore: 0.690,
                averageReliability: averageReliability,
                independentSignalCount: 5,
                conflictingSignalCount: 1,      // penalty held at 0.92 to isolate the margin effect
                freshnessFactor: 0.96,
                explicitInputFactor: 0.80
            )
        )
        #expect(confidence.overall > 0.72)
        let outcome = AdaptationOutcomeSelector(configuration: .production).outcome(for: confidence.overall)
        #expect(outcome == .applied)
    }
}
