import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Adaptation timeline & undo (Section B.20, B.24 item 29) and Live-Activity
/// style session exit criteria (B.21 analogue at the history level).
struct TimelineUndoTests {
    private func makeStore(history: AdaptationHistory = .empty) -> AdaptationTimelineStore {
        AdaptationTimelineStore(
            history: history,
            clock: TestSupport.clock,
            idGenerator: CountingIDGenerator()
        )
    }

    private func makeAppliedDecision() async -> AdaptationDecision {
        let engine = TransparentAdaptiveDecisionEngine(
            configuration: .unitTest, scoring: .production,
            clock: TestSupport.clock, idGenerator: CountingIDGenerator()
        )
        let snapshot = SimulationScenario.sunnyOutdoorAfternoon.snapshot(at: TestSupport.referenceDate)
        return await engine.evaluate(snapshot: snapshot, preferences: .default, history: .empty)
    }

    // 29. Undo restores the previous mode.
    @Test
    func undoRestoresPreviousModeAndRecordsReversion() async throws {
        let store = makeStore()
        let decision = await makeAppliedDecision()
        #expect(decision.outcome == .applied)
        await store.record(decision: decision, wasAutomatic: true)
        var history = await store.history
        #expect(history.currentMode == .outdoorVisibility)
        #expect(history.lastAutomaticChangeAt != nil)

        let result = await store.undoLastAppliedAdaptation(preferences: .default)
        let restored = try #require(result)
        #expect(restored.restoredMode == .balanced)
        history = await store.history
        #expect(history.currentMode == .balanced)
        // The undone change's cooldown is invalidated.
        #expect(history.lastAutomaticChangeAt == nil)
        let lastEntry = try #require(history.entries.last)
        #expect(lastEntry.userResponse == .reverted)
        #expect(lastEntry.endReason == .undone)
        // A smoothed learning step, not a global punishment.
        let adjustment = restored.updatedPreferences.personalization[.outdoorVisibility]?.boundedAdjustment ?? 0
        #expect(adjustment < 0)
        #expect(adjustment >= -0.02)
    }

    @Test
    func undoWithNothingAppliedReturnsNil() async {
        let store = makeStore()
        let result = await store.undoLastAppliedAdaptation(preferences: .default)
        #expect(result == nil)
    }

    @Test
    func suggestionsDoNotMoveTheCurrentMode() async {
        let store = makeStore()
        let engine = TransparentAdaptiveDecisionEngine(
            configuration: .unitTest, scoring: .production,
            clock: TestSupport.clock, idGenerator: CountingIDGenerator()
        )
        let snapshot = SimulationScenario.lateNightProlongedSession.snapshot(at: TestSupport.referenceDate)
        let decision = await engine.evaluate(snapshot: snapshot, preferences: .default, history: .empty)
        #expect(decision.outcome == .suggested)
        await store.record(decision: decision, wasAutomatic: true)
        let history = await store.history
        #expect(history.currentMode == .balanced)
        #expect(history.lastAutomaticChangeAt == nil)
    }

    @Test
    func manualOverrideLifecycleUpdatesHistory() async {
        let store = makeStore()
        let override = ManualModeOverride(
            mode: .focus, startedAt: TestSupport.referenceDate,
            expiresAt: TestSupport.referenceDate.addingTimeInterval(1800), source: .dashboard
        )
        await store.beginOverride(override)
        var history = await store.history
        #expect(history.currentMode == .focus)
        #expect(history.activeOverride == override)
        #expect(history.lastOverrideStartedAt == override.startedAt)
        await store.endOverride()
        history = await store.history
        #expect(history.activeOverride == nil)
        // The start marker persists so stale cooldowns stay invalidated.
        #expect(history.lastOverrideStartedAt == override.startedAt)
    }

    @Test
    func retentionDropsOldEntries() async {
        let old = AdaptationTimelineEntry(
            id: TestSupport.uuid(60),
            timestamp: TestSupport.referenceDate.addingTimeInterval(-40 * 24 * 3600),
            previousMode: .balanced, selectedMode: .calm, outcome: .applied,
            confidence: 0.8, topReasons: ["Rainy weather"], wasAutomatic: true
        )
        let recent = AdaptationTimelineEntry(
            id: TestSupport.uuid(61),
            timestamp: TestSupport.referenceDate.addingTimeInterval(-3600),
            previousMode: .calm, selectedMode: .focus, outcome: .applied,
            confidence: 0.8, topReasons: ["Focus goal"], wasAutomatic: true
        )
        let store = makeStore(history: AdaptationHistory(entries: [old, recent]))
        await store.applyRetention(maxAge: 30 * 24 * 3600)
        let history = await store.history
        #expect(history.entries.count == 1)
        #expect(history.entries.first?.id == recent.id)
    }

    @Test
    func deleteAllErasesEverything() async {
        let store = makeStore()
        let decision = await makeAppliedDecision()
        await store.record(decision: decision, wasAutomatic: true)
        await store.deleteAll()
        let history = await store.history
        #expect(history.entries.isEmpty)
        #expect(history.currentMode == .balanced)
    }

    @Test
    func feedbackOnLatestEntryUpdatesPreferences() async {
        let store = makeStore()
        let decision = await makeAppliedDecision()
        await store.record(decision: decision, wasAutomatic: true)
        let updated = await store.recordFeedback(.helpful, preferences: .default)
        let state = updated.personalization[.outdoorVisibility]
        #expect(state?.helpfulCount == 1)
        #expect((state?.boundedAdjustment ?? 0) > 0)
        let history = await store.history
        #expect(history.entries.last?.userResponse == .helpful)
    }
}
