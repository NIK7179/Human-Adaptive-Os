import Foundation

// MARK: - Explainability contract (Section B.18)

public struct ExplanationFactor: Identifiable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let explanation: String
    public let contribution: Double
    public let source: ContextSignalSource
    public let isApproximation: Bool
    /// Which signal kind produced this factor (used by fingerprints).
    public let signalKind: ContextSignalKind?

    public init(
        id: UUID,
        title: String,
        explanation: String,
        contribution: Double,
        source: ContextSignalSource,
        isApproximation: Bool,
        signalKind: ContextSignalKind?
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.contribution = contribution
        self.source = source
        self.isApproximation = isApproximation
        self.signalKind = signalKind
    }
}

public struct IgnoredSignal: Codable, Sendable {
    public let kind: ContextSignalKind
    public let reason: String

    public init(kind: ContextSignalKind, reason: String) {
        self.kind = kind
        self.reason = reason
    }
}

public struct UnavailableSignal: Codable, Sendable {
    public let name: String
    public let reason: String

    public init(name: String, reason: String) {
        self.name = name
        self.reason = reason
    }
}

public struct AdaptationExplanation: Identifiable, Codable, Sendable {
    public let id: UUID
    public let generatedAt: Date
    public let headline: String
    public let summary: String
    public let selectedMode: AdaptiveMode
    public let outcome: AdaptationOutcome
    public let confidence: DecisionConfidence
    public let topPositiveFactors: [ExplanationFactor]
    public let topNegativeFactors: [ExplanationFactor]
    public let ignoredSignals: [IgnoredSignal]
    public let unavailableSignals: [UnavailableSignal]
    public let privacySummary: String
    public let dataSourcesUsed: [ContextSignalSource]
    public let dataSourcesNotUsed: [ContextSignalSource]
    public let undoDescription: String

    public init(
        id: UUID,
        generatedAt: Date,
        headline: String,
        summary: String,
        selectedMode: AdaptiveMode,
        outcome: AdaptationOutcome,
        confidence: DecisionConfidence,
        topPositiveFactors: [ExplanationFactor],
        topNegativeFactors: [ExplanationFactor],
        ignoredSignals: [IgnoredSignal],
        unavailableSignals: [UnavailableSignal],
        privacySummary: String,
        dataSourcesUsed: [ContextSignalSource],
        dataSourcesNotUsed: [ContextSignalSource],
        undoDescription: String
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.headline = headline
        self.summary = summary
        self.selectedMode = selectedMode
        self.outcome = outcome
        self.confidence = confidence
        self.topPositiveFactors = topPositiveFactors
        self.topNegativeFactors = topNegativeFactors
        self.ignoredSignals = ignoredSignals
        self.unavailableSignals = unavailableSignals
        self.privacySummary = privacySummary
        self.dataSourcesUsed = dataSourcesUsed
        self.dataSourcesNotUsed = dataSourcesNotUsed
        self.undoDescription = undoDescription
    }
}

// MARK: - Validation

public enum ExplanationValidationError: Error, Equatable, Sendable {
    case emptyHeadline
    case emptySummary
    case adaptationWithoutContributingFactor
    case missingUndoInstructions
    case dataSourceMismatch
    case claimsUnavailableInformation
    case prohibitedDiagnosticLanguage(term: String)
}

/// No adaptation ships without a valid explanation (Section B.18).
public struct ExplanationValidator: Sendable {
    public let contributionEpsilon: Double

    /// Terms that would turn an interface-comfort product into an implied
    /// medical/psychological diagnosis. Case-insensitive substring match.
    public static let prohibitedTerms: [String] = [
        "depress", "anxiet", "anxious", "diagnos", "disorder", "mental illness",
        "clinical", "adhd", "insomnia", "burnout", "therapy", "symptom",
    ]

    public init(contributionEpsilon: Double = 0.0001) {
        self.contributionEpsilon = contributionEpsilon
    }

    public func validate(explanation: AdaptationExplanation, contributingSources: Set<ContextSignalSource>) throws {
        if explanation.headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ExplanationValidationError.emptyHeadline
        }
        if explanation.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ExplanationValidationError.emptySummary
        }
        let changed = explanation.outcome == .applied || explanation.outcome == .suggested
        if changed {
            let hasContribution = explanation.topPositiveFactors.contains {
                abs($0.contribution) > contributionEpsilon
            }
            if !hasContribution {
                throw ExplanationValidationError.adaptationWithoutContributingFactor
            }
            if explanation.undoDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ExplanationValidationError.missingUndoInstructions
            }
        }
        // dataSourcesUsed must exactly match the actual contributing signals.
        if Set(explanation.dataSourcesUsed) != contributingSources {
            throw ExplanationValidationError.dataSourceMismatch
        }
        // The explanation may not claim use of sources listed as unused.
        if !Set(explanation.dataSourcesUsed).isDisjoint(with: Set(explanation.dataSourcesNotUsed)) {
            throw ExplanationValidationError.claimsUnavailableInformation
        }
        let allText = (
            [explanation.headline, explanation.summary, explanation.privacySummary, explanation.undoDescription]
            + explanation.topPositiveFactors.map(\.explanation)
            + explanation.topNegativeFactors.map(\.explanation)
        ).joined(separator: " ").lowercased()
        for term in Self.prohibitedTerms where allText.contains(term) {
            throw ExplanationValidationError.prohibitedDiagnosticLanguage(term: term)
        }
    }
}

/// Validates a decision's explanation against the decision's own recorded
/// factor sources — the engine builds those directly from contributing
/// votes, so a mismatch with `dataSourcesUsed` means the explanation lies.
public func validateExplanation(for decision: AdaptationDecision) throws {
    let validator = ExplanationValidator()
    let factorSources = Set(
        (decision.explanation.topPositiveFactors + decision.explanation.topNegativeFactors)
            .map(\.source)
    )
    try validator.validate(explanation: decision.explanation, contributingSources: factorSources)
}
