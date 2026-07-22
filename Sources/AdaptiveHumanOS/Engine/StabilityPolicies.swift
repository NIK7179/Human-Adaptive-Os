import Foundation

// MARK: - Hysteresis (Section B.10)

/// A new mode must beat the current mode's score by a margin before the
/// engine will move. Manual selections pay no hysteresis; urgent outdoor
/// visibility pays a reduced one; low-confidence inferred mood pays more.
public struct HysteresisPolicy: Sendable {
    public let configuration: AdaptiveEngineConfiguration

    public init(configuration: AdaptiveEngineConfiguration) {
        self.configuration = configuration
    }

    public func requiredMargin(
        candidate: AdaptiveMode,
        moodIsInferredOnly: Bool
    ) -> Double {
        if candidate == .outdoorVisibility {
            return configuration.urgentVisibilityHysteresis
        }
        if moodIsInferredOnly {
            return configuration.inferredMoodHysteresis
        }
        return configuration.normalHysteresis
    }

    /// True when the candidate clears hysteresis against the current mode.
    public func candidateClears(
        candidateScore: Double,
        currentModeScore: Double,
        candidate: AdaptiveMode,
        moodIsInferredOnly: Bool
    ) -> Bool {
        let margin = requiredMargin(candidate: candidate, moodIsInferredOnly: moodIsInferredOnly)
        return candidateScore - currentModeScore >= margin
    }
}

// MARK: - Cooldown (Section B.11)

public struct CooldownPolicy: Sendable {
    public let configuration: AdaptiveEngineConfiguration

    public init(configuration: AdaptiveEngineConfiguration) {
        self.configuration = configuration
    }

    public func cooldownDuration(after mode: AdaptiveMode) -> TimeInterval {
        switch mode {
        case .outdoorVisibility: return configuration.outdoorCooldown
        case .sleepPreparation: return configuration.sleepCooldown
        default: return configuration.defaultCooldown
        }
    }

    /// Whether an automatic primary-mode change is currently blocked.
    ///
    /// Cooldown never blocks: explicit user selection, user cancellation,
    /// critical visibility adaptation, accessibility requirements, or
    /// thermal/low-power modifiers (those bypass this check entirely).
    ///
    /// Override-expiration rule (B.11): a cooldown that began BEFORE the most
    /// recent manual override started is ignored once the override ends — a
    /// mode must not remain stale because an old cooldown overlaps the
    /// override's end.
    public func isCoolingDown(
        at evaluationTime: Date,
        history: AdaptationHistory,
        candidate: AdaptiveMode
    ) -> Bool {
        guard let lastChange = history.lastAutomaticChangeAt else { return false }
        if let overrideStart = history.lastOverrideStartedAt,
           history.activeOverride == nil,
           lastChange <= overrideStart {
            return false
        }
        let changedMode = history.lastAutomaticChangeMode ?? history.currentMode
        let duration = cooldownDuration(after: changedMode)
        let elapsed = evaluationTime.timeIntervalSince(lastChange)
        guard elapsed < duration else { return false }
        // Critical visibility bypasses cooldown (B.11 / B.24 item 19).
        if candidate == .outdoorVisibility { return false }
        return true
    }
}
