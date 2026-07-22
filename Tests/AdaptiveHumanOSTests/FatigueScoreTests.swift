import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Interaction-fatigue score (Section B.17).
struct FatigueScoreTests {
    private let calculator = FatigueScoreCalculator()

    // 21. Inferred fatigue is capped at 0.75 without explicit tiredness.
    @Test
    func inferredFatigueIsCappedWithoutExplicitTiredness() throws {
        let input = FatigueInput(
            continuousSessionMinutes: 300,   // saturates the session component
            rapidNavigationRate: 1.0,
            taskSwitchingRate: 1.0,
            minutesSinceLastBreak: 300,
            isLateNight: true,
            explicitTiredness: nil
        )
        let score = try #require(calculator.calculate(input: input))
        #expect(score <= 0.75 + 1e-12)
        #expect(score > 0.7)   // maximal evidence should sit at the cap
    }

    @Test
    func explicitTirednessCanExceedTheInferredCap() throws {
        let input = FatigueInput(
            continuousSessionMinutes: 300,
            rapidNavigationRate: 1.0,
            taskSwitchingRate: 1.0,
            minutesSinceLastBreak: 300,
            isLateNight: true,
            explicitTiredness: 1.0
        )
        let score = try #require(calculator.calculate(input: input))
        #expect(score > 0.75)
        #expect(score <= 1.0)
    }

    @Test
    func noBehavioralEvidenceYieldsNilNotZero() {
        let input = FatigueInput(
            continuousSessionMinutes: nil, rapidNavigationRate: nil,
            taskSwitchingRate: nil, minutesSinceLastBreak: nil,
            isLateNight: true, explicitTiredness: nil
        )
        #expect(calculator.calculate(input: input) == nil)
        #expect(calculator.level(input: input) == .unavailable)
    }

    @Test
    func shortRelaxedSessionScoresLow() throws {
        let input = FatigueInput(
            continuousSessionMinutes: 10, rapidNavigationRate: 0.1,
            taskSwitchingRate: 0.1, minutesSinceLastBreak: 10,
            isLateNight: false, explicitTiredness: nil
        )
        let score = try #require(calculator.calculate(input: input))
        #expect(score < 0.35)
        #expect(InteractionFatigueLevel(score: score) == .low)
    }

    @Test
    func levelBandsMatchDocumentedRanges() {
        #expect(InteractionFatigueLevel(score: 0.0) == .low)
        #expect(InteractionFatigueLevel(score: 0.34) == .low)
        #expect(InteractionFatigueLevel(score: 0.35) == .moderate)
        #expect(InteractionFatigueLevel(score: 0.64) == .moderate)
        #expect(InteractionFatigueLevel(score: 0.65) == .high)
        #expect(InteractionFatigueLevel(score: 1.0) == .high)
        #expect(InteractionFatigueLevel(score: nil) == .unavailable)
    }

    @Test
    func missingComponentsRenormalizeRatherThanZeroFill() throws {
        // Only the session component available, fully saturated: the result
        // reflects that evidence rather than being dragged down by absent
        // components.
        let input = FatigueInput(
            continuousSessionMinutes: 240, rapidNavigationRate: nil,
            taskSwitchingRate: nil, minutesSinceLastBreak: nil,
            isLateNight: false, explicitTiredness: nil
        )
        let score = try #require(calculator.calculate(input: input))
        // session 1.0 (w 0.35) + lateNight 0.0 (w 0.10) → 0.35/0.45 ≈ 0.778 → capped 0.75.
        #expect(abs(score - 0.75) < 1e-9)
    }
}
