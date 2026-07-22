import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Section A gate: the keystone hands in `independentSignalCount: 5` and
/// `conflictingSignalCount: 1`; these tests DERIVE those values from the
/// five worked-example `ContextSignal`s and their `ModeVote`s through the
/// production `SignalContributionAnalyzer`.
struct SignalCountDerivationTests {
    private let analyzer = SignalContributionAnalyzer(
        contributionEpsilon: 0.0001,
        conflictContributionThreshold: 0.10
    )

    @Test
    func fiveIndependentContributingSignalsAreDerivedFromFixtureSignals() {
        let signals = TestSupport.eyeComfortFixtureSignals()
        #expect(signals.count == 5)
        let votes = TestSupport.eyeComfortFixtureVotes()
        let derived = analyzer.independentContributingSignalCount(winnerVotes: votes)
        #expect(derived == 5)
    }

    @Test
    func oneConflictingSignalIsDerivedFromFixtureVotes() {
        let votes = TestSupport.eyeComfortFixtureVotes()
        let conflicting = analyzer.conflictingSignalCount(winnerVotes: votes)
        #expect(conflicting == 1)
        // And it is specifically the positive-valence opposition.
        let kinds = analyzer.independentContributingKinds(winnerVotes: votes)
        #expect(kinds.contains(.positiveValence))
    }

    @Test
    func fixtureVoteContributionsMatchWorkedExampleWithinRoundingTolerance() {
        // The B.6A table rounds to four decimals; exact products differ by
        // < 5e-5 (e.g. lateNight 0.7374375 vs 0.7374).
        let votes = TestSupport.eyeComfortFixtureVotes()
        let expected: [ContextSignalKind: Double] = [
            .lateNight: 0.7374,
            .prolongedSession: 0.4752,
            .lowEnergy: 0.4016,
            .poorSleep: 0.2700,
            .positiveValence: -0.1260,
        ]
        for vote in votes {
            let target = expected[vote.signalKind] ?? .nan
            #expect(abs(vote.finalContribution - target) < 5e-5)
        }
    }

    @Test
    func multipleVotesFromOneSignalKindCountOnce() {
        var votes = TestSupport.eyeComfortFixtureVotes()
        // Duplicate the late-night vote (same kind, different vote ID).
        if let first = votes.first {
            votes.append(
                ModeVote(
                    id: TestSupport.uuid(200), signalID: first.signalID,
                    signalKind: first.signalKind, mode: first.mode,
                    baseWeight: 0.10, signalStrength: 0.9, reliability: 0.95,
                    preferenceModifier: 1.0, contextualModifier: 1.0,
                    explanation: "Secondary late-night vote."
                )
            )
        }
        #expect(analyzer.independentContributingSignalCount(winnerVotes: votes) == 5)
    }

    @Test
    func subThresholdOppositionIsNotCountedAsConflict() {
        // A tiny negative vote (abs ≤ 0.10) must not register as conflict.
        let weakOpposition = ModeVote(
            id: TestSupport.uuid(201), signalID: TestSupport.uuid(5),
            signalKind: .positiveValence, mode: .eyeComfort,
            baseWeight: -0.10, signalStrength: 0.5, reliability: 1.0,
            preferenceModifier: 1.0, contextualModifier: 1.0,
            explanation: "Weak opposition."
        )
        var votes = Array(TestSupport.eyeComfortFixtureVotes().prefix(4))
        votes.append(weakOpposition)
        #expect(analyzer.conflictingSignalCount(winnerVotes: votes) == 0)
        // Still an independent contributor even though not conflicting.
        #expect(analyzer.independentContributingSignalCount(winnerVotes: votes) == 5)
    }

    @Test
    func nonSupportingSignalBackingAnotherEligibleModeCountsAsConflict() {
        var winnerVotes = Array(TestSupport.eyeComfortFixtureVotes().prefix(4))
        // Rapid navigation barely opposes the winner (abs ≤ threshold, so
        // not a conflict on its own) but strongly supports Calm.
        winnerVotes.append(
            ModeVote(
                id: TestSupport.uuid(203), signalID: TestSupport.uuid(6),
                signalKind: .rapidNavigation, mode: .eyeComfort,
                baseWeight: -0.05, signalStrength: 0.9, reliability: 0.9,
                preferenceModifier: 1.0, contextualModifier: 1.0,
                explanation: "Rapid navigation slightly opposes Eye Comfort."
            )
        )
        let calmSupport = ModeVote(
            id: TestSupport.uuid(202), signalID: TestSupport.uuid(6),
            signalKind: .rapidNavigation, mode: .calm,
            baseWeight: 0.60, signalStrength: 0.9, reliability: 0.9,
            preferenceModifier: 1.0, contextualModifier: 1.0,
            explanation: "Rapid navigation supports Calm."
        )
        let conflicting = analyzer.conflictingSignalCount(
            winnerVotes: winnerVotes,
            otherEligibleModeVotes: [calmSupport]
        )
        #expect(conflicting == 1)
    }

    @Test
    func winnerSupportingSignalIsNotAConflictEvenWhenItBacksACompetitor() {
        let winnerVotes = Array(TestSupport.eyeComfortFixtureVotes().prefix(4))
        // Poor sleep positively supports the winner AND Recovery — per the
        // B.6A worked example this is NOT a conflict.
        let recoverySupport = ModeVote(
            id: TestSupport.uuid(204), signalID: TestSupport.uuid(4),
            signalKind: .poorSleep, mode: .recovery,
            baseWeight: 0.70, signalStrength: 0.75, reliability: 0.90,
            preferenceModifier: 1.0, contextualModifier: 1.0,
            explanation: "Poor sleep supports Recovery."
        )
        let conflicting = analyzer.conflictingSignalCount(
            winnerVotes: winnerVotes,
            otherEligibleModeVotes: [recoverySupport]
        )
        #expect(conflicting == 0)
    }
}
