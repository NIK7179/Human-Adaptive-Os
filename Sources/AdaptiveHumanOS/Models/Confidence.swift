import Foundation

// MARK: - Contribution-weighted reliability (Section A.5)

public struct ReliabilityVoteInput: Sendable {
    public let contribution: Double
    public let reliability: Double

    public init(contribution: Double, reliability: Double) {
        self.contribution = contribution
        self.reliability = reliability
    }
}

/// The production reliability aggregator shared by the decision engine and
/// the keystone regression fixture. Weighting by *absolute* contribution
/// means opposing evidence still counts toward evidence quality.
///
/// Returns `nil` when no vote materially contributes — the caller must treat
/// that as "reliability unknown", never as zero.
public struct ContributionWeightedReliabilityCalculator: Sendable {
    public let contributionEpsilon: Double

    public init(contributionEpsilon: Double) {
        self.contributionEpsilon = contributionEpsilon
    }

    public func calculate(votes: [ReliabilityVoteInput]) -> Double? {
        let contributing = votes.filter { abs($0.contribution) > contributionEpsilon }
        guard !contributing.isEmpty else { return nil }
        let numerator = contributing.reduce(0.0) { $0 + abs($1.contribution) * $1.reliability }
        let denominator = contributing.reduce(0.0) { $0 + abs($1.contribution) }
        guard denominator > contributionEpsilon else { return nil }
        return min(max(numerator / denominator, 0.0), 1.0)
    }
}

// MARK: - Confidence result (Section A.6 / B.8)

public struct DecisionConfidence: Codable, Sendable {
    public let overall: Double
    public let winningScore: Double
    public let runnerUpScore: Double
    public let normalizedScoreMargin: Double
    public let averageReliability: Double
    public let independentSignalFactor: Double
    public let freshnessFactor: Double
    public let explicitInputFactor: Double
    public let conflictPenalty: Double
    public let independentSignalCount: Int
    public let conflictingSignalCount: Int

    public init(
        overall: Double,
        winningScore: Double,
        runnerUpScore: Double,
        normalizedScoreMargin: Double,
        averageReliability: Double,
        independentSignalFactor: Double,
        freshnessFactor: Double,
        explicitInputFactor: Double,
        conflictPenalty: Double,
        independentSignalCount: Int,
        conflictingSignalCount: Int
    ) {
        self.overall = overall
        self.winningScore = winningScore
        self.runnerUpScore = runnerUpScore
        self.normalizedScoreMargin = normalizedScoreMargin
        self.averageReliability = averageReliability
        self.independentSignalFactor = independentSignalFactor
        self.freshnessFactor = freshnessFactor
        self.explicitInputFactor = explicitInputFactor
        self.conflictPenalty = conflictPenalty
        self.independentSignalCount = independentSignalCount
        self.conflictingSignalCount = conflictingSignalCount
    }
}

// MARK: - Configuration (Section A.6)

public struct ConfidenceConfiguration: Sendable {
    public let winningScoreWeight: Double
    public let scoreMarginWeight: Double
    public let reliabilityWeight: Double
    public let independentSignalsWeight: Double
    public let freshnessWeight: Double
    public let explicitInputWeight: Double
    public let targetDecisiveMargin: Double
    public let targetIndependentSignalCount: Int
    public let conflictPenaltyStrength: Double
    public let minimumConflictPenalty: Double
    public let suggestionThreshold: Double
    public let automaticThreshold: Double

    public init(
        winningScoreWeight: Double,
        scoreMarginWeight: Double,
        reliabilityWeight: Double,
        independentSignalsWeight: Double,
        freshnessWeight: Double,
        explicitInputWeight: Double,
        targetDecisiveMargin: Double,
        targetIndependentSignalCount: Int,
        conflictPenaltyStrength: Double,
        minimumConflictPenalty: Double,
        suggestionThreshold: Double,
        automaticThreshold: Double
    ) {
        self.winningScoreWeight = winningScoreWeight
        self.scoreMarginWeight = scoreMarginWeight
        self.reliabilityWeight = reliabilityWeight
        self.independentSignalsWeight = independentSignalsWeight
        self.freshnessWeight = freshnessWeight
        self.explicitInputWeight = explicitInputWeight
        self.targetDecisiveMargin = targetDecisiveMargin
        self.targetIndependentSignalCount = targetIndependentSignalCount
        self.conflictPenaltyStrength = conflictPenaltyStrength
        self.minimumConflictPenalty = minimumConflictPenalty
        self.suggestionThreshold = suggestionThreshold
        self.automaticThreshold = automaticThreshold
    }

    public static let production = ConfidenceConfiguration(
        winningScoreWeight: 0.30,
        scoreMarginWeight: 0.25,
        reliabilityWeight: 0.20,
        independentSignalsWeight: 0.10,
        freshnessWeight: 0.10,
        explicitInputWeight: 0.05,
        targetDecisiveMargin: 0.25,
        targetIndependentSignalCount: 4,
        conflictPenaltyStrength: 0.40,
        minimumConflictPenalty: 0.55,
        suggestionThreshold: 0.60,
        automaticThreshold: 0.72
    )
}

// MARK: - Confidence calculator (Section A.7)

public struct ConfidenceInput: Sendable {
    public let winningScore: Double
    public let runnerUpScore: Double
    public let averageReliability: Double
    public let independentSignalCount: Int
    public let conflictingSignalCount: Int
    public let freshnessFactor: Double
    public let explicitInputFactor: Double

    public init(
        winningScore: Double,
        runnerUpScore: Double,
        averageReliability: Double,
        independentSignalCount: Int,
        conflictingSignalCount: Int,
        freshnessFactor: Double,
        explicitInputFactor: Double
    ) {
        self.winningScore = winningScore
        self.runnerUpScore = runnerUpScore
        self.averageReliability = averageReliability
        self.independentSignalCount = independentSignalCount
        self.conflictingSignalCount = conflictingSignalCount
        self.freshnessFactor = freshnessFactor
        self.explicitInputFactor = explicitInputFactor
    }
}

public struct ConfidenceCalculator: Sendable {
    public let configuration: ConfidenceConfiguration

    public init(configuration: ConfidenceConfiguration) {
        self.configuration = configuration
    }

    public func calculate(input: ConfidenceInput) -> DecisionConfidence {
        let rawMargin = max(0.0, input.winningScore - input.runnerUpScore)
        let normalizedMargin = clamp(rawMargin / configuration.targetDecisiveMargin)
        let signalFactor = clamp(
            Double(input.independentSignalCount) / Double(configuration.targetIndependentSignalCount)
        )
        let conflictRatio = Double(input.conflictingSignalCount) / Double(max(1, input.independentSignalCount))
        let conflictPenalty = min(
            1.0,
            max(
                configuration.minimumConflictPenalty,
                1.0 - configuration.conflictPenaltyStrength * conflictRatio
            )
        )
        let baseConfidence =
            configuration.winningScoreWeight        * clamp(input.winningScore)
          + configuration.scoreMarginWeight         * normalizedMargin
          + configuration.reliabilityWeight         * clamp(input.averageReliability)
          + configuration.independentSignalsWeight  * signalFactor
          + configuration.freshnessWeight           * clamp(input.freshnessFactor)
          + configuration.explicitInputWeight       * clamp(input.explicitInputFactor)
        return DecisionConfidence(
            overall: clamp(baseConfidence * conflictPenalty),
            winningScore: clamp(input.winningScore),
            runnerUpScore: clamp(input.runnerUpScore),
            normalizedScoreMargin: normalizedMargin,
            averageReliability: clamp(input.averageReliability),
            independentSignalFactor: signalFactor,
            freshnessFactor: clamp(input.freshnessFactor),
            explicitInputFactor: clamp(input.explicitInputFactor),
            conflictPenalty: conflictPenalty,
            independentSignalCount: input.independentSignalCount,
            conflictingSignalCount: input.conflictingSignalCount
        )
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}

// MARK: - Outcome selection (Section A.8 — production type, not test-inline)

public struct AdaptationOutcomeSelector: Sendable {
    public let configuration: ConfidenceConfiguration

    public init(configuration: ConfidenceConfiguration) {
        self.configuration = configuration
    }

    public func outcome(for overall: Double) -> AdaptationOutcome {
        if overall < configuration.suggestionThreshold {
            return .unchangedLowConfidence
        } else if overall <= configuration.automaticThreshold {
            return .suggested
        } else {
            return .applied
        }
    }
}
