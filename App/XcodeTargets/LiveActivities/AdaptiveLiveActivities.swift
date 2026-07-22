// Xcode-only — views go in the WIDGET EXTENSION, the manager in the APP
// target (XCODE_SETUP.md steps 6 and 8). Requires NSSupportsLiveActivities
// = YES in the app's Info.plist. Full behavior (Dynamic Island, screen
// presentation) requires a PHYSICAL DEVICE; simulators render partial
// support. NOT compiled or verified on Linux CI.
//
// Exit criteria come from the Linux-tested core `AdaptiveSessionPolicy` /
// `SessionExitEvaluator` (Section B.21): no Live Activity here can exist
// without an end policy, and none runs permanently.

#if canImport(ActivityKit) && canImport(SwiftUI)
import Foundation
import ActivityKit
import SwiftUI
import AdaptiveHumanOS

// MARK: Attributes

public struct AdaptiveSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// One contextual reason line, e.g. "It is late and you have been
        /// reading for a while."
        public var reason: String
        public var endsAt: Date

        public init(reason: String, endsAt: Date) {
            self.reason = reason
            self.endsAt = endsAt
        }
    }

    public var mode: AdaptiveMode
    public var startedAt: Date

    public init(mode: AdaptiveMode, startedAt: Date) {
        self.mode = mode
        self.startedAt = startedAt
    }
}

// MARK: Session manager (app target)

/// Starts and ends Eye Comfort / Focus sessions, delegating every end
/// decision to the core `SessionExitEvaluator`.
@MainActor
public final class AdaptiveSessionManager {
    private var activity: Activity<AdaptiveSessionAttributes>?
    private var policy: AdaptiveSessionPolicy = .eyeComfort
    private let evaluator = SessionExitEvaluator()
    private let clock: any AdaptiveClock

    public init(clock: any AdaptiveClock = SystemAdaptiveClock()) {
        self.clock = clock
    }

    public var isRunning: Bool { activity != nil }

    /// Supported sessions in this phase: Eye Comfort and Focus.
    public func start(mode: AdaptiveMode, reason: String) throws {
        guard mode == .eyeComfort || mode == .focus else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw ProviderError.permissionDenied
        }
        let now = clock.now
        policy = AdaptiveSessionPolicy.policy(for: mode)
        let attributes = AdaptiveSessionAttributes(mode: mode, startedAt: now)
        let content = ActivityContent(
            state: AdaptiveSessionAttributes.ContentState(
                reason: reason,
                endsAt: now.addingTimeInterval(policy.defaultDuration)
            ),
            // The system may end a stale activity itself — belt and braces
            // on top of the policy's maximum duration.
            staleDate: now.addingTimeInterval(policy.maximumDuration)
        )
        activity = try Activity.request(attributes: attributes, content: content)
    }

    /// Call on every reevaluation tick and on user actions; ends the
    /// activity when the core policy says so.
    public func evaluateExit(
        userCancelled: Bool = false,
        goalCompleted: Bool = false,
        majorContextChange: Bool = false,
        appInactive: Bool = false,
        unhelpfulFeedback: Bool = false
    ) async {
        guard let activity else { return }
        let input = SessionEvaluationInput(
            startedAt: activity.attributes.startedAt,
            now: clock.now,
            userCancelled: userCancelled,
            goalCompleted: goalCompleted,
            majorContextChange: majorContextChange,
            appInactive: appInactive,
            unhelpfulFeedback: unhelpfulFeedback
        )
        if evaluator.endReason(policy: policy, input: input) != nil {
            await end()
        }
    }

    public func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}

// MARK: Live Activity presentation (widget extension)

struct AdaptiveSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AdaptiveSessionAttributes.self) { context in
            // Lock Screen / banner presentation.
            HStack(spacing: 12) {
                Image(systemName: context.attributes.mode == .focus ? "scope" : "eye")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(context.attributes.mode.displayName) session")
                        .font(.headline)
                    Text(context.state.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(timerInterval: context.attributes.startedAt...context.state.endsAt, countsDown: true)
                    .font(.caption.monospacedDigit())
                    .frame(width: 52)
            }
            .padding(14)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.mode == .focus ? "scope" : "eye")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.attributes.mode.displayName) session")
                        .font(.headline)
                    Text(context.state.reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startedAt...context.state.endsAt, countsDown: true)
                        .font(.caption.monospacedDigit())
                        .frame(width: 50)
                }
            } compactLeading: {
                Image(systemName: context.attributes.mode == .focus ? "scope" : "eye")
            } compactTrailing: {
                Text(timerInterval: context.attributes.startedAt...context.state.endsAt, countsDown: true)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 44)
            } minimal: {
                Image(systemName: context.attributes.mode == .focus ? "scope" : "eye")
            }
        }
    }
}
#endif
