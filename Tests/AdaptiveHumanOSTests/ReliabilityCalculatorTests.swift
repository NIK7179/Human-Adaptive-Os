import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Section A.10 — exercises the production
/// `ContributionWeightedReliabilityCalculator`, not a copy.
struct ReliabilityCalculatorTests {
    @Test
    func reliabilityUsesAbsoluteContributionWeights() {
        let calc = ContributionWeightedReliabilityCalculator(contributionEpsilon: 0.0001)
        let result = calc.calculate(votes: [
            .init(contribution:  0.7374, reliability: 0.95),
            .init(contribution:  0.4752, reliability: 0.90),
            .init(contribution:  0.4016, reliability: 1.00),
            .init(contribution:  0.2700, reliability: 0.90),
            .init(contribution: -0.1260, reliability: 1.00)
        ])
        #expect(abs((result ?? -1) - 0.9445876032235598) < 1e-6)
    }

    @Test
    func emptyVoteListYieldsNilNotZero() {
        let calc = ContributionWeightedReliabilityCalculator(contributionEpsilon: 0.0001)
        #expect(calc.calculate(votes: []) == nil)
    }

    @Test
    func votesBelowEpsilonAreExcluded() {
        let calc = ContributionWeightedReliabilityCalculator(contributionEpsilon: 0.0001)
        // The near-zero vote with terrible reliability must not drag the result down.
        let result = calc.calculate(votes: [
            .init(contribution: 0.5, reliability: 1.0),
            .init(contribution: 0.00005, reliability: 0.0)
        ])
        #expect(abs((result ?? -1) - 1.0) < 1e-12)
    }

    @Test
    func allVotesBelowEpsilonYieldNil() {
        let calc = ContributionWeightedReliabilityCalculator(contributionEpsilon: 0.0001)
        let result = calc.calculate(votes: [
            .init(contribution: 0.00005, reliability: 0.9),
            .init(contribution: -0.00002, reliability: 0.9)
        ])
        #expect(result == nil)
    }

    @Test
    func negativeContributionCountsTowardEvidenceQuality() {
        let calc = ContributionWeightedReliabilityCalculator(contributionEpsilon: 0.0001)
        let withOpposition = calc.calculate(votes: [
            .init(contribution: 0.5, reliability: 0.6),
            .init(contribution: -0.5, reliability: 1.0)
        ])
        // abs-weighted mean: (0.5×0.6 + 0.5×1.0) / 1.0 = 0.8
        #expect(abs((withOpposition ?? -1) - 0.8) < 1e-12)
    }

    @Test
    func resultIsClampedToUnitInterval() {
        let calc = ContributionWeightedReliabilityCalculator(contributionEpsilon: 0.0001)
        let result = calc.calculate(votes: [.init(contribution: 1.0, reliability: 1.0)])
        #expect((result ?? -1) <= 1.0)
        #expect((result ?? -1) >= 0.0)
    }
}
