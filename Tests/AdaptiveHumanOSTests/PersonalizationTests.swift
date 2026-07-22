import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Feedback learning bounds and smoothing (Section B.22, B.24 items 30–31).
struct PersonalizationTests {
    private let learner = PreferenceLearner()

    // 31. A single rejection does not materially alter global weights.
    @Test
    func singleRejectionHasLimitedImpact() {
        let updated = learner.applying(feedback: .reverted, for: .eyeComfort, to: .default)
        let state = updated.personalization[.eyeComfort]
        #expect(abs((state?.boundedAdjustment ?? 1)) <= 0.015 + 1e-12)
        // Below the minimum sample count, scoring still sees exactly 1.0.
        #expect(updated.preferenceModifier(for: .eyeComfort, minimumSamples: 3) == 1.0)
        // Other modes are untouched — one correction never punishes globally.
        #expect(updated.personalization[.calm] == nil)
    }

    // 30. Repeated rejection gradually adjusts personalization.
    @Test
    func repeatedRejectionGraduallyLowersModeWeight() {
        var preferences = AdaptivePreferences.default
        for _ in 0..<6 {
            preferences = learner.applying(feedback: .unhelpful, for: .eyeComfort, to: preferences)
        }
        let modifier = preferences.preferenceModifier(for: .eyeComfort, minimumSamples: 3)
        #expect(modifier < 1.0)
        #expect(modifier >= 0.75)   // bounded band
    }

    @Test
    func repeatedPositiveFeedbackIsBoundedAbove() {
        var preferences = AdaptivePreferences.default
        for _ in 0..<50 {
            preferences = learner.applying(feedback: .helpful, for: .calm, to: preferences)
        }
        let modifier = preferences.preferenceModifier(for: .calm, minimumSamples: 3)
        #expect(modifier <= 1.25)
    }

    @Test
    func minimumSampleThresholdGatesAdjustments() {
        var preferences = AdaptivePreferences.default
        preferences = learner.applying(feedback: .helpful, for: .focus, to: preferences)
        preferences = learner.applying(feedback: .helpful, for: .focus, to: preferences)
        #expect(preferences.preferenceModifier(for: .focus, minimumSamples: 3) == 1.0)
        preferences = learner.applying(feedback: .helpful, for: .focus, to: preferences)
        #expect(preferences.preferenceModifier(for: .focus, minimumSamples: 3) > 1.0)
    }

    @Test
    func resetClearsAllLearnedState() {
        var preferences = AdaptivePreferences.default
        for _ in 0..<5 {
            preferences = learner.applying(feedback: .helpful, for: .calm, to: preferences)
        }
        let cleared = learner.reset(preferences)
        #expect(cleared.personalization.isEmpty)
        #expect(cleared.preferenceModifier(for: .calm, minimumSamples: 3) == 1.0)
    }

    @Test
    func personalizationDisabledMeansNeutralModifiers() {
        var preferences = AdaptivePreferences.default
        for _ in 0..<5 {
            preferences = learner.applying(feedback: .helpful, for: .calm, to: preferences)
        }
        preferences.personalizationEnabled = false
        #expect(preferences.preferenceModifier(for: .calm, minimumSamples: 3) == 1.0)
    }
}
