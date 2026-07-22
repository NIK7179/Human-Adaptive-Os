import Foundation

// MARK: - Live Activity exit criteria (Section B.21)
//
// The POLICY is core and Linux-tested; the ActivityKit surface that obeys
// it lives in App/XcodeTargets/LiveActivities and is not verified here.
// No Live Activity may remain active without an explicit end policy.

public struct AdaptiveSessionPolicy: Codable, Sendable, Equatable {
    public let defaultDuration: TimeInterval
    public let maximumDuration: TimeInterval
    public let reevaluationInterval: TimeInterval
    public let endOnManualCancellation: Bool
    public let endOnGoalCompletion: Bool
    public let endOnMajorContextChange: Bool
    public let endWhenAppBecomesInactive: Bool

    public init(
        defaultDuration: TimeInterval,
        maximumDuration: TimeInterval,
        reevaluationInterval: TimeInterval,
        endOnManualCancellation: Bool,
        endOnGoalCompletion: Bool,
        endOnMajorContextChange: Bool,
        endWhenAppBecomesInactive: Bool
    ) {
        self.defaultDuration = defaultDuration
        self.maximumDuration = maximumDuration
        self.reevaluationInterval = reevaluationInterval
        self.endOnManualCancellation = endOnManualCancellation
        self.endOnGoalCompletion = endOnGoalCompletion
        self.endOnMajorContextChange = endOnMajorContextChange
        self.endWhenAppBecomesInactive = endWhenAppBecomesInactive
    }

    /// Focus: ends on duration, user, goal completion, or maximum.
    public static let focus = AdaptiveSessionPolicy(
        defaultDuration: 25 * 60, maximumDuration: 2 * 60 * 60, reevaluationInterval: 5 * 60,
        endOnManualCancellation: true, endOnGoalCompletion: true,
        endOnMajorContextChange: false, endWhenAppBecomesInactive: false
    )
    /// Eye Comfort: also ends on a material solar-phase change or an
    /// unhelpful report.
    public static let eyeComfort = AdaptiveSessionPolicy(
        defaultDuration: 30 * 60, maximumDuration: 3 * 60 * 60, reevaluationInterval: 10 * 60,
        endOnManualCancellation: true, endOnGoalCompletion: false,
        endOnMajorContextChange: true, endWhenAppBecomesInactive: false
    )
    /// Interview Prep: scheduled time plus buffer, user, or maximum.
    public static let interviewPreparation = AdaptiveSessionPolicy(
        defaultDuration: 60 * 60, maximumDuration: 3 * 60 * 60, reevaluationInterval: 10 * 60,
        endOnManualCancellation: true, endOnGoalCompletion: true,
        endOnMajorContextChange: false, endWhenAppBecomesInactive: false
    )
    /// Outdoor Visibility: ends when outdoor likelihood stays low or
    /// conditions change.
    public static let outdoorVisibility = AdaptiveSessionPolicy(
        defaultDuration: 20 * 60, maximumDuration: 2 * 60 * 60, reevaluationInterval: 5 * 60,
        endOnManualCancellation: true, endOnGoalCompletion: false,
        endOnMajorContextChange: true, endWhenAppBecomesInactive: true
    )

    public static func policy(for mode: AdaptiveMode) -> AdaptiveSessionPolicy {
        switch mode {
        case .focus: return .focus
        case .interviewPreparation: return .interviewPreparation
        case .outdoorVisibility: return .outdoorVisibility
        default: return .eyeComfort
        }
    }
}

public enum SessionEndReason: String, Codable, Sendable {
    case durationElapsed, maximumReached, userCancelled, goalCompleted
    case contextChanged, appInactive, unhelpfulFeedback
}

public struct SessionEvaluationInput: Sendable {
    public let startedAt: Date
    public let now: Date
    public let userCancelled: Bool
    public let goalCompleted: Bool
    public let majorContextChange: Bool
    public let appInactive: Bool
    public let unhelpfulFeedback: Bool

    public init(
        startedAt: Date,
        now: Date,
        userCancelled: Bool = false,
        goalCompleted: Bool = false,
        majorContextChange: Bool = false,
        appInactive: Bool = false,
        unhelpfulFeedback: Bool = false
    ) {
        self.startedAt = startedAt
        self.now = now
        self.userCancelled = userCancelled
        self.goalCompleted = goalCompleted
        self.majorContextChange = majorContextChange
        self.appInactive = appInactive
        self.unhelpfulFeedback = unhelpfulFeedback
    }
}

/// Deterministic exit-criteria evaluation. Returns the reason the session
/// must end now, or nil to continue.
public struct SessionExitEvaluator: Sendable {
    public init() {}

    public func endReason(policy: AdaptiveSessionPolicy, input: SessionEvaluationInput) -> SessionEndReason? {
        let elapsed = input.now.timeIntervalSince(input.startedAt)
        if input.userCancelled && policy.endOnManualCancellation { return .userCancelled }
        if elapsed >= policy.maximumDuration { return .maximumReached }
        if input.unhelpfulFeedback { return .unhelpfulFeedback }
        if input.goalCompleted && policy.endOnGoalCompletion { return .goalCompleted }
        if input.majorContextChange && policy.endOnMajorContextChange { return .contextChanged }
        if input.appInactive && policy.endWhenAppBecomesInactive { return .appInactive }
        if elapsed >= policy.defaultDuration { return .durationElapsed }
        return nil
    }
}
