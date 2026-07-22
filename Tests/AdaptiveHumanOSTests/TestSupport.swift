import Foundation
@testable import AdaptiveHumanOS

/// Deterministic test fixtures. No `Date()`/`UUID()` — IDs are built from
/// fixed bytes and timestamps from fixed epoch offsets.
enum TestSupport {
    /// A deterministic UUID whose last byte is `index` (0...255).
    static func uuid(_ index: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, index))
    }

    /// Fixed reference instant: 2026-01-15 23:24:00 UTC (a late-night hour).
    static let referenceDate = Date(timeIntervalSince1970: 1_768_519_440)

    static let clock = FixedAdaptiveClock(now: referenceDate)

    /// The five Eye Comfort fixture signals from the Section B.6A worked
    /// example (11:24 PM, 68-minute session, low energy, 5h sleep, positive
    /// mood).
    static func eyeComfortFixtureSignals() -> [ContextSignal] {
        [
            ContextSignal(
                id: uuid(1), kind: .lateNight, normalizedValue: 0.90, reliability: 0.95,
                source: .solarModel, timestamp: referenceDate, expiresAt: nil,
                isApproximation: false, explanation: "It is 11:24 PM, well after sunset."
            ),
            ContextSignal(
                id: uuid(2), kind: .prolongedSession, normalizedValue: 0.80, reliability: 0.90,
                source: .interactionHistory, timestamp: referenceDate, expiresAt: nil,
                isApproximation: false, explanation: "Continuous 68-minute session."
            ),
            ContextSignal(
                id: uuid(3), kind: .lowEnergy, normalizedValue: 0.85, reliability: 1.00,
                source: .userInput, timestamp: referenceDate, expiresAt: nil,
                isApproximation: false, explanation: "You reported low energy."
            ),
            ContextSignal(
                id: uuid(4), kind: .poorSleep, normalizedValue: 0.75, reliability: 0.90,
                source: .healthKit, timestamp: referenceDate, expiresAt: nil,
                isApproximation: false, explanation: "About 5 hours of sleep last night."
            ),
            ContextSignal(
                id: uuid(5), kind: .positiveValence, normalizedValue: 0.70, reliability: 1.00,
                source: .userInput, timestamp: referenceDate, expiresAt: nil,
                isApproximation: false, explanation: "You reported a positive mood."
            ),
        ]
    }

    /// The Eye Comfort votes those five signals cast in the worked example.
    /// (base, strength, reliability, preference, contextual) per B.6A table.
    static func eyeComfortFixtureVotes() -> [ModeVote] {
        let signals = eyeComfortFixtureSignals()
        let parameters: [(base: Double, ctx: Double)] = [
            (0.75, 1.15),   // lateNight
            (0.60, 1.10),   // prolongedSession
            (0.45, 1.05),   // lowEnergy
            (0.40, 1.00),   // poorSleep
            (-0.18, 1.00),  // positiveValence
        ]
        return zip(signals, parameters).enumerated().map { index, pair in
            let (signal, parameter) = pair
            return ModeVote(
                id: uuid(UInt8(100 + index)),
                signalID: signal.id,
                signalKind: signal.kind,
                mode: .eyeComfort,
                baseWeight: parameter.base,
                signalStrength: signal.normalizedValue,
                reliability: signal.reliability,
                preferenceModifier: 1.00,
                contextualModifier: parameter.ctx,
                explanation: signal.explanation
            )
        }
    }
}
