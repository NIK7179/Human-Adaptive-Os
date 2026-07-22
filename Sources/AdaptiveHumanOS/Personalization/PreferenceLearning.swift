import Foundation

// MARK: - Bounded, smoothed personalization (Section B.22)
//
// Adjusts mode weights gradually from explicit feedback. Never overrides
// explicit user input, accessibility or safety; never converts weak
// evidence into automatic adaptation; requires a minimum number of
// comparable feedback events before a weight moves at all; smoothing keeps
// any single response from having a large impact.

public enum AdaptationFeedback: String, Codable, Sendable {
    case helpful, unhelpful, kept, reverted
}

public struct PreferenceLearner: Sendable {
    /// Adjustment applied per feedback event, before smoothing bounds.
    public let stepSize: Double
    /// `boundedAdjustment` never leaves this band (modifier 0.75...1.25).
    public let adjustmentBound: Double
    /// Events required before adjustments take effect in scoring.
    public let minimumSamples: Int

    public init(stepSize: Double = 0.03, adjustmentBound: Double = 0.25, minimumSamples: Int = 3) {
        self.stepSize = stepSize
        self.adjustmentBound = adjustmentBound
        self.minimumSamples = minimumSamples
    }

    /// Returns updated preferences after one feedback event on one mode.
    /// A single event moves the bounded adjustment by at most `stepSize` —
    /// one correction never punishes a mode globally (B.20 rule 5).
    public func applying(
        feedback: AdaptationFeedback,
        for mode: AdaptiveMode,
        to preferences: AdaptivePreferences
    ) -> AdaptivePreferences {
        var updated = preferences
        var state = updated.personalization[mode] ?? ModePersonalization()
        switch feedback {
        case .helpful:
            state.helpfulCount += 1
            state.boundedAdjustment = clampAdjustment(state.boundedAdjustment + stepSize)
        case .kept:
            state.acceptedCount += 1
            state.boundedAdjustment = clampAdjustment(state.boundedAdjustment + stepSize * 0.5)
        case .unhelpful:
            state.unhelpfulCount += 1
            state.boundedAdjustment = clampAdjustment(state.boundedAdjustment - stepSize)
        case .reverted:
            state.rejectedCount += 1
            // Reversions count, but only repeated rejections meaningfully
            // reduce the weight (undo rule 3).
            state.boundedAdjustment = clampAdjustment(state.boundedAdjustment - stepSize * 0.5)
        }
        updated.personalization[mode] = state
        return updated
    }

    /// Full reset of learned preferences ("Reset learned preferences").
    public func reset(_ preferences: AdaptivePreferences) -> AdaptivePreferences {
        var updated = preferences
        updated.personalization = [:]
        return updated
    }

    private func clampAdjustment(_ value: Double) -> Double {
        min(max(value, -adjustmentBound), adjustmentBound)
    }
}
