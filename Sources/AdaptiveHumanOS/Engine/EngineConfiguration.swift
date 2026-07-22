import Foundation

/// Central engine tuning (Section B.23). Production, conservative, demo and
/// unit-test variants — demo reacts faster but is clearly separated from
/// production behavior.
public struct AdaptiveEngineConfiguration: Codable, Sendable {
    public let automaticAdaptationConfidence: Double
    public let suggestionConfidence: Double
    public let minimumScoreMargin: Double
    public let normalHysteresis: Double
    public let urgentVisibilityHysteresis: Double
    public let inferredMoodHysteresis: Double
    public let defaultCooldown: TimeInterval
    public let outdoorCooldown: TimeInterval
    public let sleepCooldown: TimeInterval
    public let minimumIndependentSignals: Int
    public let fatigueExpirationInterval: TimeInterval
    public let personalizationMinimumSamples: Int
    public let contributionEpsilon: Double
    public let conflictContributionThreshold: Double
    public let minimumEvidenceCoverage: Double
    public let defaultReevaluationInterval: TimeInterval

    public init(
        automaticAdaptationConfidence: Double,
        suggestionConfidence: Double,
        minimumScoreMargin: Double,
        normalHysteresis: Double,
        urgentVisibilityHysteresis: Double,
        inferredMoodHysteresis: Double,
        defaultCooldown: TimeInterval,
        outdoorCooldown: TimeInterval,
        sleepCooldown: TimeInterval,
        minimumIndependentSignals: Int,
        fatigueExpirationInterval: TimeInterval,
        personalizationMinimumSamples: Int,
        contributionEpsilon: Double,
        conflictContributionThreshold: Double,
        minimumEvidenceCoverage: Double,
        defaultReevaluationInterval: TimeInterval
    ) {
        self.automaticAdaptationConfidence = automaticAdaptationConfidence
        self.suggestionConfidence = suggestionConfidence
        self.minimumScoreMargin = minimumScoreMargin
        self.normalHysteresis = normalHysteresis
        self.urgentVisibilityHysteresis = urgentVisibilityHysteresis
        self.inferredMoodHysteresis = inferredMoodHysteresis
        self.defaultCooldown = defaultCooldown
        self.outdoorCooldown = outdoorCooldown
        self.sleepCooldown = sleepCooldown
        self.minimumIndependentSignals = minimumIndependentSignals
        self.fatigueExpirationInterval = fatigueExpirationInterval
        self.personalizationMinimumSamples = personalizationMinimumSamples
        self.contributionEpsilon = contributionEpsilon
        self.conflictContributionThreshold = conflictContributionThreshold
        self.minimumEvidenceCoverage = minimumEvidenceCoverage
        self.defaultReevaluationInterval = defaultReevaluationInterval
    }

    public static let production = AdaptiveEngineConfiguration(
        automaticAdaptationConfidence: 0.72,
        suggestionConfidence: 0.60,
        minimumScoreMargin: 0.12,
        normalHysteresis: 0.12,
        urgentVisibilityHysteresis: 0.05,
        inferredMoodHysteresis: 0.20,
        defaultCooldown: 20 * 60,
        outdoorCooldown: 5 * 60,
        sleepCooldown: 30 * 60,
        minimumIndependentSignals: 2,
        fatigueExpirationInterval: 45 * 60,
        personalizationMinimumSamples: 3,
        contributionEpsilon: 0.0001,
        conflictContributionThreshold: 0.10,
        minimumEvidenceCoverage: 0.65,
        defaultReevaluationInterval: 10 * 60
    )

    public static let conservative = AdaptiveEngineConfiguration(
        automaticAdaptationConfidence: 0.80,
        suggestionConfidence: 0.68,
        minimumScoreMargin: 0.16,
        normalHysteresis: 0.18,
        urgentVisibilityHysteresis: 0.08,
        inferredMoodHysteresis: 0.26,
        defaultCooldown: 40 * 60,
        outdoorCooldown: 10 * 60,
        sleepCooldown: 45 * 60,
        minimumIndependentSignals: 3,
        fatigueExpirationInterval: 45 * 60,
        personalizationMinimumSamples: 5,
        contributionEpsilon: 0.0001,
        conflictContributionThreshold: 0.10,
        minimumEvidenceCoverage: 0.70,
        defaultReevaluationInterval: 20 * 60
    )

    /// Faster reactions for stage demos. Never ship as production behavior.
    public static let demo = AdaptiveEngineConfiguration(
        automaticAdaptationConfidence: 0.72,
        suggestionConfidence: 0.60,
        minimumScoreMargin: 0.08,
        normalHysteresis: 0.08,
        urgentVisibilityHysteresis: 0.03,
        inferredMoodHysteresis: 0.14,
        defaultCooldown: 60,
        outdoorCooldown: 15,
        sleepCooldown: 90,
        minimumIndependentSignals: 2,
        fatigueExpirationInterval: 10 * 60,
        personalizationMinimumSamples: 2,
        contributionEpsilon: 0.0001,
        conflictContributionThreshold: 0.10,
        minimumEvidenceCoverage: 0.65,
        defaultReevaluationInterval: 30
    )

    /// Deterministic values for unit tests; thresholds identical to
    /// production so fixtures stay meaningful.
    public static let unitTest = AdaptiveEngineConfiguration(
        automaticAdaptationConfidence: 0.72,
        suggestionConfidence: 0.60,
        minimumScoreMargin: 0.12,
        normalHysteresis: 0.12,
        urgentVisibilityHysteresis: 0.05,
        inferredMoodHysteresis: 0.20,
        defaultCooldown: 20 * 60,
        outdoorCooldown: 5 * 60,
        sleepCooldown: 30 * 60,
        minimumIndependentSignals: 2,
        fatigueExpirationInterval: 45 * 60,
        personalizationMinimumSamples: 3,
        contributionEpsilon: 0.0001,
        conflictContributionThreshold: 0.10,
        minimumEvidenceCoverage: 0.65,
        defaultReevaluationInterval: 10 * 60
    )

    /// The confidence sub-configuration matching these thresholds.
    public var confidenceConfiguration: ConfidenceConfiguration {
        ConfidenceConfiguration(
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
            suggestionThreshold: suggestionConfidence,
            automaticThreshold: automaticAdaptationConfidence
        )
    }
}
