import Foundation

// MARK: - Adaptation timeline (Section B.20)

public enum AdaptationUserResponse: String, Codable, Sendable {
    case kept, reverted, helpful, unhelpful, adjusted, ignored
}

public enum AdaptationEndReason: String, Codable, Sendable {
    case userEnded, expired, replacedByNewDecision, undone, goalCompleted, contextChanged
}

public struct AdaptationTimelineEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let previousMode: AdaptiveMode
    public let selectedMode: AdaptiveMode
    public let outcome: AdaptationOutcome
    public let confidence: Double
    public let topReasons: [String]
    public let wasAutomatic: Bool
    public var userResponse: AdaptationUserResponse?
    public var endedAt: Date?
    public var endReason: AdaptationEndReason?

    public init(
        id: UUID,
        timestamp: Date,
        previousMode: AdaptiveMode,
        selectedMode: AdaptiveMode,
        outcome: AdaptationOutcome,
        confidence: Double,
        topReasons: [String],
        wasAutomatic: Bool,
        userResponse: AdaptationUserResponse? = nil,
        endedAt: Date? = nil,
        endReason: AdaptationEndReason? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.previousMode = previousMode
        self.selectedMode = selectedMode
        self.outcome = outcome
        self.confidence = confidence
        self.topReasons = topReasons
        self.wasAutomatic = wasAutomatic
        self.userResponse = userResponse
        self.endedAt = endedAt
        self.endReason = endReason
    }
}

/// The engine's view of the past: enough to enforce hysteresis, cooldown and
/// override rules deterministically. All fields injected — the engine never
/// reads ambient state.
public struct AdaptationHistory: Codable, Sendable {
    public var currentMode: AdaptiveMode
    /// When the last *automatic* primary-mode change was applied.
    public var lastAutomaticChangeAt: Date?
    /// Mode selected by that last automatic change.
    public var lastAutomaticChangeMode: AdaptiveMode?
    public var activeOverride: ManualModeOverride?
    /// When the most recent manual override started, kept after expiry so
    /// stale pre-override cooldowns can be invalidated (Section B.11).
    public var lastOverrideStartedAt: Date?
    public var entries: [AdaptationTimelineEntry]

    public init(
        currentMode: AdaptiveMode = .balanced,
        lastAutomaticChangeAt: Date? = nil,
        lastAutomaticChangeMode: AdaptiveMode? = nil,
        activeOverride: ManualModeOverride? = nil,
        lastOverrideStartedAt: Date? = nil,
        entries: [AdaptationTimelineEntry] = []
    ) {
        self.currentMode = currentMode
        self.lastAutomaticChangeAt = lastAutomaticChangeAt
        self.lastAutomaticChangeMode = lastAutomaticChangeMode
        self.activeOverride = activeOverride
        self.lastOverrideStartedAt = lastOverrideStartedAt
        self.entries = entries
    }

    public static let empty = AdaptationHistory()
}
