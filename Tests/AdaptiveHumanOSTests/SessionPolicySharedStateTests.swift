import Testing
import Foundation
@testable import AdaptiveHumanOS

/// B.21 session exit criteria (B.24 item 32) and the App Group shared-state
/// codec — the Linux-testable halves of the Live Activity / widget work.
struct SessionPolicySharedStateTests {
    private let evaluator = SessionExitEvaluator()
    private let start = TestSupport.referenceDate

    @Test
    func focusSessionEndsOnDurationGoalUserAndMaximum() {
        let policy = AdaptiveSessionPolicy.focus
        #expect(evaluator.endReason(policy: policy, input: .init(startedAt: start, now: start.addingTimeInterval(10 * 60))) == nil)
        #expect(evaluator.endReason(policy: policy, input: .init(startedAt: start, now: start.addingTimeInterval(26 * 60))) == .durationElapsed)
        #expect(evaluator.endReason(policy: policy, input: .init(startedAt: start, now: start.addingTimeInterval(5 * 60), userCancelled: true)) == .userCancelled)
        #expect(evaluator.endReason(policy: policy, input: .init(startedAt: start, now: start.addingTimeInterval(5 * 60), goalCompleted: true)) == .goalCompleted)
        #expect(evaluator.endReason(policy: policy, input: .init(startedAt: start, now: start.addingTimeInterval(3 * 60 * 60))) == .maximumReached)
    }

    @Test
    func eyeComfortEndsOnSolarChangeAndUnhelpfulReport() {
        let policy = AdaptiveSessionPolicy.eyeComfort
        #expect(evaluator.endReason(policy: policy, input: .init(startedAt: start, now: start.addingTimeInterval(5 * 60), majorContextChange: true)) == .contextChanged)
        #expect(evaluator.endReason(policy: policy, input: .init(startedAt: start, now: start.addingTimeInterval(5 * 60), unhelpfulFeedback: true)) == .unhelpfulFeedback)
        // Goal completion is not an eye-comfort end criterion.
        #expect(evaluator.endReason(policy: policy, input: .init(startedAt: start, now: start.addingTimeInterval(5 * 60), goalCompleted: true)) == nil)
    }

    @Test
    func outdoorVisibilityEndsWhenAppBecomesInactive() {
        let policy = AdaptiveSessionPolicy.outdoorVisibility
        #expect(evaluator.endReason(policy: policy, input: .init(startedAt: start, now: start.addingTimeInterval(2 * 60), appInactive: true)) == .appInactive)
        #expect(evaluator.endReason(policy: AdaptiveSessionPolicy.focus, input: .init(startedAt: start, now: start.addingTimeInterval(2 * 60), appInactive: true)) == nil)
    }

    @Test
    func everyPolicyHasABoundedMaximumDuration() {
        for mode in AdaptiveMode.allCases {
            let policy = AdaptiveSessionPolicy.policy(for: mode)
            #expect(policy.maximumDuration > 0)
            #expect(policy.maximumDuration <= 4 * 60 * 60)
            #expect(policy.defaultDuration <= policy.maximumDuration)
            #expect(policy.endOnManualCancellation)   // the user can ALWAYS end a session
        }
    }

    // MARK: Shared state codec (App Group serialization)

    private var sampleState: SharedAdaptiveState {
        SharedAdaptiveState(
            mode: .eyeComfort,
            headline: "Eye Comfort might help right now",
            confidence: 0.6833730781418192,
            outcome: .suggested,
            isSimulated: true,
            automaticAdaptationEnabled: true,
            updatedAt: TestSupport.referenceDate
        )
    }

    @Test
    func sharedStateRoundTripsExactly() throws {
        let serializer = SharedStateSerializer()
        let data = try serializer.encode(sampleState)
        let decoded = try serializer.decode(data)
        #expect(decoded == sampleState)
    }

    @Test
    func sharedStateEncodingIsByteDeterministic() throws {
        let serializer = SharedStateSerializer()
        let first = try serializer.encode(sampleState)
        let second = try serializer.encode(sampleState)
        #expect(first == second)
    }

    @Test
    func sharedStateContainsNoSensitivePayload() throws {
        // Presentation intent only: the widget payload must never carry
        // mood, health, or location values.
        let serializer = SharedStateSerializer()
        let json = String(decoding: try serializer.encode(sampleState), as: UTF8.self).lowercased()
        for forbidden in ["valence", "energy", "sleep", "mood", "latitude", "longitude", "health"] {
            #expect(!json.contains(forbidden), "shared state leaked field containing `\(forbidden)`")
        }
    }

    @Test
    func corruptAndFutureVersionPayloadsAreRejected() {
        let serializer = SharedStateSerializer()
        #expect(throws: SharedStateError.corruptPayload) {
            _ = try serializer.decode(Data("not json".utf8))
        }
        let future = SharedAdaptiveState(
            version: 99, mode: .balanced, headline: "x", confidence: 0.5,
            outcome: .suggested, isSimulated: false,
            automaticAdaptationEnabled: true, updatedAt: TestSupport.referenceDate
        )
        #expect(throws: SharedStateError.unsupportedVersion(99)) {
            _ = try serializer.decode(try SharedStateSerializer().encode(future))
        }
    }
}
