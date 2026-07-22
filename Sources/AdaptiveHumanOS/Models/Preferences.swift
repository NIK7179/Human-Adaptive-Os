import Foundation

/// Per-mode learned personalization state (Section B.22). Weight adjustment
/// is bounded, smoothed, and requires a minimum number of comparable
/// feedback events before it moves at all.
public struct ModePersonalization: Codable, Sendable, Equatable {
    public var acceptedCount: Int
    public var rejectedCount: Int
    public var helpfulCount: Int
    public var unhelpfulCount: Int
    /// Bounded adjustment; `preferenceModifier = 1.0 + boundedAdjustment`,
    /// clamped to 0.75...1.25 overall.
    public var boundedAdjustment: Double

    public init(
        acceptedCount: Int = 0,
        rejectedCount: Int = 0,
        helpfulCount: Int = 0,
        unhelpfulCount: Int = 0,
        boundedAdjustment: Double = 0.0
    ) {
        self.acceptedCount = acceptedCount
        self.rejectedCount = rejectedCount
        self.helpfulCount = helpfulCount
        self.unhelpfulCount = unhelpfulCount
        self.boundedAdjustment = boundedAdjustment
    }

    public var totalFeedbackCount: Int {
        acceptedCount + rejectedCount + helpfulCount + unhelpfulCount
    }

    public var preferenceModifier: Double {
        min(max(1.0 + boundedAdjustment, 0.75), 1.25)
    }
}

/// User-controlled settings plus learned personalization. Learned weights
/// never override explicit user input, accessibility, or safety (B.22).
public struct AdaptivePreferences: Codable, Sendable {
    public var automaticAdaptationEnabled: Bool
    /// 0.0 (very conservative) ... 1.0 (very responsive); scales hysteresis.
    public var adaptationSensitivity: Double
    public var interactionEstimateEnabled: Bool
    public var reducedStimulationPreferred: Bool
    public var disabledModes: Set<AdaptiveMode>
    public var personalization: [AdaptiveMode: ModePersonalization]
    public var personalizationEnabled: Bool
    /// True when the user recently completed an explicit check-in.
    public var hasRecentExplicitCheckIn: Bool

    public init(
        automaticAdaptationEnabled: Bool = true,
        adaptationSensitivity: Double = 0.5,
        interactionEstimateEnabled: Bool = false,
        reducedStimulationPreferred: Bool = false,
        disabledModes: Set<AdaptiveMode> = [],
        personalization: [AdaptiveMode: ModePersonalization] = [:],
        personalizationEnabled: Bool = true,
        hasRecentExplicitCheckIn: Bool = false
    ) {
        self.automaticAdaptationEnabled = automaticAdaptationEnabled
        self.adaptationSensitivity = adaptationSensitivity
        self.interactionEstimateEnabled = interactionEstimateEnabled
        self.reducedStimulationPreferred = reducedStimulationPreferred
        self.disabledModes = disabledModes
        self.personalization = personalization
        self.personalizationEnabled = personalizationEnabled
        self.hasRecentExplicitCheckIn = hasRecentExplicitCheckIn
    }

    public static let `default` = AdaptivePreferences()

    /// The multiplier a mode's votes receive from learned preferences.
    /// Returns exactly 1.0 when personalization is off or under-sampled.
    public func preferenceModifier(for mode: AdaptiveMode, minimumSamples: Int) -> Double {
        guard personalizationEnabled,
              let state = personalization[mode],
              state.totalFeedbackCount >= minimumSamples else {
            return 1.0
        }
        return state.preferenceModifier
    }
}

/// Manual override (Section B.12). The engine keeps evaluating during an
/// override but never replaces the manual mode.
public enum ManualOverrideSource: String, Codable, Sendable {
    case dashboard, widget, appIntent, liveActivity, lifeMode
}

public struct ManualModeOverride: Codable, Sendable, Equatable {
    public let mode: AdaptiveMode
    public let startedAt: Date
    public let expiresAt: Date?
    public let source: ManualOverrideSource

    public init(mode: AdaptiveMode, startedAt: Date, expiresAt: Date?, source: ManualOverrideSource) {
        self.mode = mode
        self.startedAt = startedAt
        self.expiresAt = expiresAt
        self.source = source
    }

    public func isActive(at evaluationTime: Date) -> Bool {
        guard startedAt <= evaluationTime else { return false }
        guard let expiresAt else { return true }
        return evaluationTime < expiresAt
    }
}
