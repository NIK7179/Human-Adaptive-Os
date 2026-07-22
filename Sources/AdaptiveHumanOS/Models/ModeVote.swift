import Foundation

/// A weighted vote a single context signal casts for (or against) a mode.
///
/// `finalContribution = baseWeight × signalStrength × reliability
///                    × preferenceModifier × contextualModifier`
///
/// Ranges (Section B.5):
/// - baseWeight:         -1.0 ... 1.0 (negative votes are allowed)
/// - signalStrength:      0.0 ... 1.0
/// - reliability:         0.0 ... 1.0
/// - preferenceModifier:  0.5 ... 1.5
/// - contextualModifier:  0.5 ... 1.5
public struct ModeVote: Identifiable, Codable, Sendable {
    public let id: UUID
    public let signalID: UUID
    public let signalKind: ContextSignalKind
    public let mode: AdaptiveMode
    public let baseWeight: Double
    public let signalStrength: Double
    public let reliability: Double
    public let preferenceModifier: Double
    public let contextualModifier: Double
    public let finalContribution: Double
    public let explanation: String

    public init(
        id: UUID,
        signalID: UUID,
        signalKind: ContextSignalKind,
        mode: AdaptiveMode,
        baseWeight: Double,
        signalStrength: Double,
        reliability: Double,
        preferenceModifier: Double,
        contextualModifier: Double,
        explanation: String
    ) {
        self.id = id
        self.signalID = signalID
        self.signalKind = signalKind
        self.mode = mode
        self.baseWeight = baseWeight
        self.signalStrength = signalStrength
        self.reliability = reliability
        self.preferenceModifier = preferenceModifier
        self.contextualModifier = contextualModifier
        self.finalContribution = ModeVoteCalculator().contribution(
            baseWeight: baseWeight,
            signalStrength: signalStrength,
            reliability: reliability,
            preferenceModifier: preferenceModifier,
            contextualModifier: contextualModifier
        )
        self.explanation = explanation
    }
}

public struct ModeVoteCalculator: Sendable {
    public init() {}

    public func contribution(
        baseWeight: Double,
        signalStrength: Double,
        reliability: Double,
        preferenceModifier: Double,
        contextualModifier: Double
    ) -> Double {
        baseWeight * signalStrength * reliability * preferenceModifier * contextualModifier
    }
}
