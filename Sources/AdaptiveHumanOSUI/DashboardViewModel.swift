#if canImport(SwiftUI)
import SwiftUI
import Observation
import AdaptiveHumanOS

/// Drives the Today dashboard. Wires the deterministic engine to the UI and
/// simulation scenarios. Everything runs on-device; simulation state is
/// clearly labeled throughout.
@MainActor
@Observable
public final class DashboardViewModel {
    public private(set) var decision: AdaptationDecision?
    public private(set) var history: AdaptationHistory = .empty
    public private(set) var comfort: ComfortScoreResult?
    public private(set) var fatigueLevel: InteractionFatigueLevel = .unavailable
    public private(set) var isEvaluating = false
    public var preferences = AdaptivePreferences(hasRecentExplicitCheckIn: true)
    public var scenario: SimulationScenario = .lateNightProlongedSession {
        didSet { evaluate() }
    }

    /// The mode currently governing the interface.
    public var activeMode: AdaptiveMode { history.currentMode }

    public var activeTheme: AdaptiveTheme {
        decision.map { decision in
            // The applied theme follows the *current* mode, not a pending
            // suggestion.
            decision.selectedMode == history.currentMode
                ? decision.theme
                : AdaptiveTheme.base(for: history.currentMode)
        } ?? AdaptiveTheme.base(for: history.currentMode)
    }

    public var pendingSuggestion: AdaptationDecision? {
        guard let decision, decision.outcome == .suggested else { return nil }
        return decision
    }

    private let engine: TransparentAdaptiveDecisionEngine
    private let store: AdaptationTimelineStore
    private let clock: any AdaptiveClock
    private let learner = PreferenceLearner()
    private let fatigueCalculator = FatigueScoreCalculator()
    private let comfortCalculator = ComfortScoreCalculator()

    public init(
        clock: any AdaptiveClock = SystemAdaptiveClock(),
        idGenerator: any AdaptiveIDGenerating = SystemIDGenerator(),
        configuration: AdaptiveEngineConfiguration = .demo
    ) {
        self.clock = clock
        self.engine = TransparentAdaptiveDecisionEngine(
            configuration: configuration,
            scoring: .production,
            clock: clock,
            idGenerator: idGenerator
        )
        self.store = AdaptationTimelineStore(clock: clock, idGenerator: idGenerator)
        evaluate()
    }

    public var snapshot: ContextSnapshot { scenario.snapshot(at: clock.now) }

    public func evaluate() {
        isEvaluating = true
        Task {
            let snapshot = self.snapshot
            let result = await engine.evaluate(
                snapshot: snapshot,
                preferences: preferences,
                history: await store.history
            )
            await store.record(decision: result, wasAutomatic: true)
            self.history = await store.history
            self.decision = result
            self.refreshScores(snapshot: snapshot)
            self.isEvaluating = false
        }
    }

    public func acceptSuggestion() {
        guard let suggestion = pendingSuggestion else { return }
        Task {
            await store.acceptSuggestion(mode: suggestion.selectedMode)
            preferences = await store.recordFeedback(.kept, preferences: preferences)
            self.history = await store.history
            evaluate()
        }
    }

    public func dismissSuggestion() {
        Task {
            preferences = await store.recordFeedback(.unhelpful, preferences: preferences)
            self.decision = nil
            evaluate()
        }
    }

    public func undoLastAdaptation() {
        Task {
            if let result = await store.undoLastAppliedAdaptation(preferences: preferences) {
                preferences = result.updatedPreferences
            }
            self.history = await store.history
            evaluate()
        }
    }

    public func beginManualOverride(mode: AdaptiveMode, duration: TimeInterval?) {
        Task {
            let now = clock.now
            let override = ManualModeOverride(
                mode: mode,
                startedAt: now,
                expiresAt: duration.map { now.addingTimeInterval($0) },
                source: .dashboard
            )
            await store.beginOverride(override)
            self.history = await store.history
            evaluate()
        }
    }

    public func endManualOverride() {
        Task {
            await store.endOverride()
            self.history = await store.history
            evaluate()
        }
    }

    public func sendFeedback(_ feedback: AdaptationFeedback) {
        Task {
            preferences = await store.recordFeedback(feedback, preferences: preferences)
        }
    }

    public func recordMoodCheckIn() {
        preferences.hasRecentExplicitCheckIn = true
        evaluate()
    }

    public func resetLearnedPreferences() {
        preferences = learner.reset(preferences)
        evaluate()
    }

    /// Full local wipe: timeline history plus learned preferences.
    public func deleteAllData() {
        Task {
            await store.deleteAll()
            preferences = learner.reset(preferences)
            self.history = await store.history
            evaluate()
        }
    }

    public var timelineEntries: [AdaptationTimelineEntry] {
        history.entries.reversed()
    }

    private func refreshScores(snapshot: ContextSnapshot) {
        fatigueLevel = fatigueCalculator.level(
            input: FatigueInput(
                continuousSessionMinutes: snapshot.continuousSessionMinutes,
                rapidNavigationRate: snapshot.rapidNavigationRate,
                taskSwitchingRate: nil,
                minutesSinceLastBreak: snapshot.minutesSinceLastBreak,
                isLateNight: snapshot.localHour >= 22 || snapshot.localHour < 5,
                explicitTiredness: snapshot.explicitTiredness
            )
        )
        var factors: [ComfortFactorInput] = []
        let feedbackCount = history.entries.filter { $0.userResponse != nil }.count
        if feedbackCount > 0 {
            let helpful = history.entries.filter {
                $0.userResponse == .helpful || $0.userResponse == .kept
            }.count
            factors.append(
                ComfortFactorInput(
                    kind: .explicitRecentFeedback,
                    value: Double(helpful) / Double(feedbackCount),
                    observationCount: feedbackCount
                )
            )
        }
        let modeEntries = history.entries.filter { $0.selectedMode == activeMode }
        if !modeEntries.isEmpty {
            let kept = modeEntries.filter { $0.userResponse != .reverted && $0.userResponse != .unhelpful }.count
            factors.append(
                ComfortFactorInput(
                    kind: .currentModeHistoricalEffectiveness,
                    value: Double(kept) / Double(modeEntries.count),
                    observationCount: modeEntries.count
                )
            )
        }
        factors.append(
            ComfortFactorInput(
                kind: .visualAccessibilityAlignment,
                value: snapshot.accessibility.reduceMotionEnabled || snapshot.accessibility.increaseContrastEnabled
                    ? (decision?.modifiers.reduceMotion == true || decision?.modifiers.increaseContrast == true ? 1.0 : 0.4)
                    : 0.8,
                observationCount: 6
            )
        )
        if snapshot.continuousSessionMinutes != nil {
            let fatigueAligned: Double
            switch fatigueLevel {
            case .high: fatigueAligned = activeMode == .eyeComfort || activeMode == .recovery ? 1.0 : 0.35
            case .moderate: fatigueAligned = 0.65
            case .low, .unavailable: fatigueAligned = 0.85
            }
            factors.append(
                ComfortFactorInput(kind: .sessionFatigueAlignment, value: fatigueAligned, observationCount: 6)
            )
        }
        if snapshot.ambientLight != nil {
            let visibilityAligned = snapshot.ambientLight == .directSunlight
                ? (activeMode == .outdoorVisibility ? 1.0 : 0.4)
                : 0.8
            factors.append(
                ComfortFactorInput(kind: .environmentalVisibilityAlignment, value: visibilityAligned, observationCount: 6)
            )
        }
        comfort = comfortCalculator.calculate(factors: factors)
    }
}
#endif
