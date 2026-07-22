import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Hysteresis (B.10), cooldown (B.11) and override-expiration rules.
struct StabilityPolicyTests {
    private let hysteresis = HysteresisPolicy(configuration: .unitTest)
    private let cooldown = CooldownPolicy(configuration: .unitTest)

    @Test
    func hysteresisMarginsMatchConfiguredDefaults() {
        #expect(hysteresis.requiredMargin(candidate: .calm, moodIsInferredOnly: false) == 0.12)
        #expect(hysteresis.requiredMargin(candidate: .outdoorVisibility, moodIsInferredOnly: false) == 0.05)
        #expect(hysteresis.requiredMargin(candidate: .calm, moodIsInferredOnly: true) == 0.20)
    }

    @Test
    func candidateBelowMarginDoesNotClear() {
        #expect(!hysteresis.candidateClears(
            candidateScore: 0.70, currentModeScore: 0.60,
            candidate: .calm, moodIsInferredOnly: false
        ))
        #expect(hysteresis.candidateClears(
            candidateScore: 0.73, currentModeScore: 0.60,
            candidate: .calm, moodIsInferredOnly: false
        ))
    }

    @Test
    func inferredMoodRequiresLargerMargin() {
        // 0.15 clears the normal margin but not the inferred-mood margin.
        #expect(hysteresis.candidateClears(
            candidateScore: 0.75, currentModeScore: 0.60,
            candidate: .calm, moodIsInferredOnly: false
        ))
        #expect(!hysteresis.candidateClears(
            candidateScore: 0.75, currentModeScore: 0.60,
            candidate: .calm, moodIsInferredOnly: true
        ))
    }

    @Test
    func cooldownDurationsFollowModeSpecificRules() {
        #expect(cooldown.cooldownDuration(after: .calm) == 20 * 60)
        #expect(cooldown.cooldownDuration(after: .outdoorVisibility) == 5 * 60)
        #expect(cooldown.cooldownDuration(after: .sleepPreparation) == 30 * 60)
    }

    @Test
    func recentAutomaticChangeBlocksNonUrgentCandidates() {
        let history = AdaptationHistory(
            currentMode: .calm,
            lastAutomaticChangeAt: TestSupport.referenceDate.addingTimeInterval(-10 * 60),
            lastAutomaticChangeMode: .calm
        )
        #expect(cooldown.isCoolingDown(at: TestSupport.referenceDate, history: history, candidate: .focus))
    }

    @Test
    func elapsedCooldownNoLongerBlocks() {
        let history = AdaptationHistory(
            currentMode: .calm,
            lastAutomaticChangeAt: TestSupport.referenceDate.addingTimeInterval(-21 * 60),
            lastAutomaticChangeMode: .calm
        )
        #expect(!cooldown.isCoolingDown(at: TestSupport.referenceDate, history: history, candidate: .focus))
    }

    @Test
    func outdoorVisibilityCandidateBypassesCooldown() {
        let history = AdaptationHistory(
            currentMode: .calm,
            lastAutomaticChangeAt: TestSupport.referenceDate.addingTimeInterval(-2 * 60),
            lastAutomaticChangeMode: .calm
        )
        #expect(!cooldown.isCoolingDown(
            at: TestSupport.referenceDate, history: history, candidate: .outdoorVisibility
        ))
    }

    /// Section B.11 override-expiration rule: a cooldown that began before
    /// the override started is ignored once the override ends.
    @Test
    func preOverrideCooldownIsIgnoredAfterOverrideExpires() {
        let history = AdaptationHistory(
            currentMode: .calm,
            lastAutomaticChangeAt: TestSupport.referenceDate.addingTimeInterval(-15 * 60),
            lastAutomaticChangeMode: .calm,
            activeOverride: nil,   // override has ended
            lastOverrideStartedAt: TestSupport.referenceDate.addingTimeInterval(-10 * 60)
        )
        #expect(!cooldown.isCoolingDown(at: TestSupport.referenceDate, history: history, candidate: .focus))
    }

    @Test
    func cooldownStartedAfterOverrideStillApplies() {
        let history = AdaptationHistory(
            currentMode: .calm,
            lastAutomaticChangeAt: TestSupport.referenceDate.addingTimeInterval(-5 * 60),
            lastAutomaticChangeMode: .calm,
            activeOverride: nil,
            lastOverrideStartedAt: TestSupport.referenceDate.addingTimeInterval(-60 * 60)
        )
        #expect(cooldown.isCoolingDown(at: TestSupport.referenceDate, history: history, candidate: .focus))
    }

    @Test
    func overrideActivityWindowIsRespected() {
        let override = ManualModeOverride(
            mode: .calm,
            startedAt: TestSupport.referenceDate.addingTimeInterval(-30 * 60),
            expiresAt: TestSupport.referenceDate.addingTimeInterval(30 * 60),
            source: .dashboard
        )
        #expect(override.isActive(at: TestSupport.referenceDate))
        #expect(!override.isActive(at: TestSupport.referenceDate.addingTimeInterval(31 * 60)))
        #expect(!override.isActive(at: TestSupport.referenceDate.addingTimeInterval(-31 * 60)))
        let openEnded = ManualModeOverride(
            mode: .focus, startedAt: TestSupport.referenceDate, expiresAt: nil, source: .appIntent
        )
        #expect(openEnded.isActive(at: TestSupport.referenceDate.addingTimeInterval(9999)))
    }

    /// B.11: after an override expires the engine reevaluates immediately —
    /// end-to-end through the engine, the stale cooldown does not pin the mode.
    @Test
    func engineMovesFreelyAfterOverrideExpiryDespiteStaleCooldown() async {
        let engine = TransparentAdaptiveDecisionEngine(
            configuration: .unitTest, scoring: .production,
            clock: TestSupport.clock, idGenerator: CountingIDGenerator()
        )
        let history = AdaptationHistory(
            currentMode: .calm,
            lastAutomaticChangeAt: TestSupport.referenceDate.addingTimeInterval(-6 * 60),
            lastAutomaticChangeMode: .calm,
            activeOverride: nil,
            lastOverrideStartedAt: TestSupport.referenceDate.addingTimeInterval(-4 * 60)
        )
        let snapshot = SimulationScenario.sunnyOutdoorAfternoon.snapshot(at: TestSupport.referenceDate)
        let decision = await engine.evaluate(snapshot: snapshot, preferences: .default, history: history)
        #expect(decision.outcome == .applied)
        #expect(decision.selectedMode == .outdoorVisibility)
    }
}
