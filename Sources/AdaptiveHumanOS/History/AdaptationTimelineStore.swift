import Foundation

/// In-memory adaptation timeline with undo (Section B.20). An actor so the
/// app, widgets-to-be and tests share one serialized mutation path. SwiftData
/// persistence layers on top of this in the app target; the core stays
/// platform-agnostic.
public actor AdaptationTimelineStore {
    public private(set) var history: AdaptationHistory
    private let clock: any AdaptiveClock
    private let idGenerator: any AdaptiveIDGenerating
    private let learner: PreferenceLearner

    public init(
        history: AdaptationHistory = .empty,
        clock: any AdaptiveClock,
        idGenerator: any AdaptiveIDGenerating,
        learner: PreferenceLearner = PreferenceLearner()
    ) {
        self.history = history
        self.clock = clock
        self.idGenerator = idGenerator
        self.learner = learner
    }

    /// Records a decision. Only `.applied` decisions and accepted
    /// suggestions move the current mode.
    @discardableResult
    public func record(decision: AdaptationDecision, wasAutomatic: Bool) async -> AdaptationTimelineEntry {
        let entry = AdaptationTimelineEntry(
            id: await idGenerator.makeID(),
            timestamp: decision.evaluatedAt,
            previousMode: decision.previousMode,
            selectedMode: decision.selectedMode,
            outcome: decision.outcome,
            confidence: decision.confidence.overall,
            topReasons: decision.explanation.topPositiveFactors.map(\.title),
            wasAutomatic: wasAutomatic
        )
        history.entries.append(entry)
        if decision.outcome == .applied {
            history.currentMode = decision.selectedMode
            if wasAutomatic {
                history.lastAutomaticChangeAt = decision.evaluatedAt
                history.lastAutomaticChangeMode = decision.selectedMode
            }
        }
        return entry
    }

    /// The user accepts a suggestion: applies the suggested mode manually
    /// (no cooldown starts — this is user action, not automatic change).
    public func acceptSuggestion(mode: AdaptiveMode) {
        history.currentMode = mode
    }

    /// Begins a manual override (Section B.12).
    public func beginOverride(_ override: ManualModeOverride) {
        history.activeOverride = override
        history.lastOverrideStartedAt = override.startedAt
        history.currentMode = override.mode
    }

    /// Ends the active override; the next evaluation reevaluates immediately
    /// and ignores stale pre-override cooldowns (Section B.11).
    public func endOverride() {
        history.activeOverride = nil
    }

    /// Undo the most recent applied adaptation (Section B.20):
    /// 1. restore the previous mode, 2. record the reversion,
    /// 3. adjust preference weights only via the learner's smoothed step,
    /// 4. the caller starts a short learning cooldown,
    /// 5. one correction never punishes a mode globally.
    @discardableResult
    public func undoLastAppliedAdaptation(
        preferences: AdaptivePreferences
    ) -> (restoredMode: AdaptiveMode, updatedPreferences: AdaptivePreferences)? {
        guard let index = history.entries.lastIndex(where: { $0.outcome == .applied && $0.endReason == nil }) else {
            return nil
        }
        var entry = history.entries[index]
        entry.userResponse = .reverted
        entry.endedAt = clock.now
        entry.endReason = .undone
        history.entries[index] = entry
        history.currentMode = entry.previousMode
        // Invalidate the cooldown that the undone change started.
        if history.lastAutomaticChangeAt == entry.timestamp {
            history.lastAutomaticChangeAt = nil
            history.lastAutomaticChangeMode = nil
        }
        let updated = learner.applying(feedback: .reverted, for: entry.selectedMode, to: preferences)
        return (entry.previousMode, updated)
    }

    /// Marks user feedback on the latest entry and returns learner-updated
    /// preferences.
    public func recordFeedback(
        _ feedback: AdaptationFeedback,
        preferences: AdaptivePreferences
    ) -> AdaptivePreferences {
        guard let index = history.entries.indices.last else { return preferences }
        var entry = history.entries[index]
        switch feedback {
        case .helpful: entry.userResponse = .helpful
        case .unhelpful: entry.userResponse = .unhelpful
        case .kept: entry.userResponse = .kept
        case .reverted: entry.userResponse = .reverted
        }
        history.entries[index] = entry
        return learner.applying(feedback: feedback, for: entry.selectedMode, to: preferences)
    }

    /// Retention (Section C.20): drop entries older than the retention window.
    public func applyRetention(maxAge: TimeInterval) {
        let cutoff = clock.now.addingTimeInterval(-maxAge)
        history.entries.removeAll { $0.timestamp < cutoff }
    }

    /// Complete deletion ("delete data").
    public func deleteAll() {
        history = .empty
    }
}
