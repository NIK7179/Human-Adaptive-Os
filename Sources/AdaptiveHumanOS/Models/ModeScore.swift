import Foundation

/// Bounded monotonic score normalization.
///
/// The logistic deliberately compresses large positive raw scores so that two
/// strongly-supported modes yield a *small* normalized margin and route to
/// `.suggested` rather than a silent switch. Do NOT raise the temperature
/// merely to widen margins — any temperature change requires recalculating
/// the Section B.6A worked example, recalibrating every simulation scenario,
/// revalidating the suggest/apply thresholds, updating the regression
/// fixtures, and documenting the intended behavioral change.
///
/// We never normalize by dividing by the max candidate score: that would
/// manufacture confidence when all evidence is weak.
public struct LogisticScoreNormalizer: Sendable {
    public let temperature: Double

    public init(temperature: Double = 1.0) {
        precondition(temperature > 0)
        self.temperature = temperature
    }

    public func normalize(rawScore: Double) -> Double {
        1.0 / (1.0 + exp(-rawScore / temperature))
    }
}

/// A candidate mode's aggregated score with full contributor provenance.
public struct ModeScore: Identifiable, Codable, Sendable {
    public let id: UUID
    public let mode: AdaptiveMode
    public let rawScore: Double
    public let normalizedScore: Double
    public let positiveContributors: [ModeVote]
    public let negativeContributors: [ModeVote]
    public let exclusionReasons: [String]
    public let isEligible: Bool

    public init(
        id: UUID,
        mode: AdaptiveMode,
        rawScore: Double,
        normalizedScore: Double,
        positiveContributors: [ModeVote],
        negativeContributors: [ModeVote],
        exclusionReasons: [String] = [],
        isEligible: Bool = true
    ) {
        self.id = id
        self.mode = mode
        self.rawScore = rawScore
        self.normalizedScore = normalizedScore
        self.positiveContributors = positiveContributors
        self.negativeContributors = negativeContributors
        self.exclusionReasons = exclusionReasons
        self.isEligible = isEligible
    }
}
