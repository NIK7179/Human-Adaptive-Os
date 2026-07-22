import Foundation

// MARK: - Interventions

public enum InterventionKind: String, Codable, CaseIterable, Sendable {
    case takeBreak, eyeRest, breathe, prepareForSleep, checkIn
    case increaseContrast, startFocusSession, reviewInterviewNotes, stepOutside
}

public struct Intervention: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let kind: InterventionKind
    public let title: String
    public let detail: String

    public init(id: UUID, kind: InterventionKind, title: String, detail: String) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

// MARK: - Decision (Section B.19)

public struct AdaptationDecision: Identifiable, Codable, Sendable {
    public let id: UUID
    public let evaluatedAt: Date
    public let previousMode: AdaptiveMode
    public let selectedMode: AdaptiveMode
    public let outcome: AdaptationOutcome
    /// All candidate scores, preserved for debugging and simulation.
    public let modeScores: [ModeScore]
    public let confidence: DecisionConfidence
    public let theme: AdaptiveTheme
    public let resolvedTheme: ResolvedAdaptiveTheme
    public let modifiers: AdaptationModifiers
    public let suggestedInterventions: [Intervention]
    public let explanation: AdaptationExplanation
    public let reevaluateAfter: TimeInterval
    public let manualOverride: ManualModeOverride?

    public init(
        id: UUID,
        evaluatedAt: Date,
        previousMode: AdaptiveMode,
        selectedMode: AdaptiveMode,
        outcome: AdaptationOutcome,
        modeScores: [ModeScore],
        confidence: DecisionConfidence,
        theme: AdaptiveTheme,
        resolvedTheme: ResolvedAdaptiveTheme,
        modifiers: AdaptationModifiers,
        suggestedInterventions: [Intervention],
        explanation: AdaptationExplanation,
        reevaluateAfter: TimeInterval,
        manualOverride: ManualModeOverride?
    ) {
        self.id = id
        self.evaluatedAt = evaluatedAt
        self.previousMode = previousMode
        self.selectedMode = selectedMode
        self.outcome = outcome
        self.modeScores = modeScores
        self.confidence = confidence
        self.theme = theme
        self.resolvedTheme = resolvedTheme
        self.modifiers = modifiers
        self.suggestedInterventions = suggestedInterventions
        self.explanation = explanation
        self.reevaluateAfter = reevaluateAfter
        self.manualOverride = manualOverride
    }
}

// MARK: - Semantic fingerprint (Section B.23A)
//
// Determinism tests compare fingerprints, not synthesized equality over
// volatile metadata (IDs, timestamps).

public struct ModeScoreFingerprint: Equatable, Sendable {
    public let mode: AdaptiveMode
    public let roundedRawScore: Double
    public let roundedNormalizedScore: Double
    public let isEligible: Bool

    public init(score: ModeScore, precision: Double = 1e-9) {
        self.mode = score.mode
        self.roundedRawScore = (score.rawScore / precision).rounded() * precision
        self.roundedNormalizedScore = (score.normalizedScore / precision).rounded() * precision
        self.isEligible = score.isEligible
    }
}

public struct AdaptationDecisionFingerprint: Equatable, Sendable {
    public let previousMode: AdaptiveMode
    public let selectedMode: AdaptiveMode
    public let outcome: AdaptationOutcome
    public let roundedModeScores: [ModeScoreFingerprint]
    public let roundedConfidence: Double
    public let modifiers: AdaptationModifiers
    public let interventionKinds: [InterventionKind]
    public let explanationFactorKinds: [ContextSignalKind]
    public let reevaluationInterval: TimeInterval

    public init(decision: AdaptationDecision, precision: Double = 1e-9) {
        self.previousMode = decision.previousMode
        self.selectedMode = decision.selectedMode
        self.outcome = decision.outcome
        self.roundedModeScores = decision.modeScores.map { ModeScoreFingerprint(score: $0, precision: precision) }
        self.roundedConfidence = (decision.confidence.overall / precision).rounded() * precision
        self.modifiers = decision.modifiers
        self.interventionKinds = decision.suggestedInterventions.map(\.kind)
        self.explanationFactorKinds = decision.explanation.topPositiveFactors.compactMap(\.signalKind)
        self.reevaluationInterval = decision.reevaluateAfter
    }
}
