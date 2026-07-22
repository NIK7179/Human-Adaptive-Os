import Foundation

/// Derives the confidence inputs that describe evidence breadth and internal
/// disagreement (Section B.6A definitions). This is production logic — the
/// keystone fixture hands the counts in, but a dedicated test derives them
/// from real `ContextSignal`s/`ModeVote`s through this type.
public struct SignalContributionAnalyzer: Sendable {
    /// Votes at or below this absolute contribution are treated as
    /// non-contributing everywhere (reliability weighting, independence,
    /// explanation factors).
    public let contributionEpsilon: Double

    /// A signal only counts as *conflicting* when its opposing contribution
    /// is material. CALIBRATION NOTE (Section B.6A): this constant is
    /// load-bearing. The worked example's positive-valence contribution
    /// (0.1260) sits just above 0.10; raising the threshold to 0.13 removes
    /// the conflict penalty and flips the fixture outcome from `.suggested`
    /// to eligible-for-automatic. Any change must rerun the representative
    /// scenario tests and revalidate the suggest/apply boundary.
    public let conflictContributionThreshold: Double

    public init(contributionEpsilon: Double = 0.0001, conflictContributionThreshold: Double = 0.10) {
        self.contributionEpsilon = contributionEpsilon
        self.conflictContributionThreshold = conflictContributionThreshold
    }

    /// Independent contributing signal = a distinct `ContextSignalKind` with
    /// at least one vote affecting the winner where
    /// `abs(finalContribution) > contributionEpsilon`. Multiple votes from
    /// one signal kind count once.
    public func independentContributingKinds(winnerVotes: [ModeVote]) -> Set<ContextSignalKind> {
        Set(
            winnerVotes
                .filter { abs($0.finalContribution) > contributionEpsilon }
                .map(\.signalKind)
        )
    }

    public func independentContributingSignalCount(winnerVotes: [ModeVote]) -> Int {
        independentContributingKinds(winnerVotes: winnerVotes).count
    }

    /// Conflicting signal = an independent contributing signal that
    /// materially opposes the winner, with
    /// `abs(net winner contribution) > conflictContributionThreshold`; or one
    /// whose winner contribution is non-positive while it materially
    /// supports another *eligible* mode.
    ///
    /// A signal that positively supports the winner is NOT a conflict even
    /// when it also supports a competitor — in the B.6A worked example poor
    /// sleep supports both Eye Comfort and Recovery, yet only the opposing
    /// positive-valence signal counts (`conflictingSignalCount = 1`).
    public func conflictingSignalCount(
        winnerVotes: [ModeVote],
        otherEligibleModeVotes: [ModeVote] = []
    ) -> Int {
        let independentKinds = independentContributingKinds(winnerVotes: winnerVotes)
        var netByKind: [ContextSignalKind: Double] = [:]
        for vote in winnerVotes {
            netByKind[vote.signalKind, default: 0.0] += vote.finalContribution
        }
        var conflicting: Set<ContextSignalKind> = []
        for kind in independentKinds {
            let net = netByKind[kind] ?? 0.0
            if net < 0, abs(net) > conflictContributionThreshold {
                conflicting.insert(kind)
                continue
            }
            if net <= 0 {
                let materiallySupportsCompetitor = otherEligibleModeVotes.contains {
                    $0.signalKind == kind && $0.finalContribution > conflictContributionThreshold
                }
                if materiallySupportsCompetitor {
                    conflicting.insert(kind)
                }
            }
        }
        return conflicting.count
    }

    /// Reliability inputs for the winner's votes, ready for
    /// `ContributionWeightedReliabilityCalculator`.
    public func reliabilityInputs(winnerVotes: [ModeVote]) -> [ReliabilityVoteInput] {
        winnerVotes.map { ReliabilityVoteInput(contribution: $0.finalContribution, reliability: $0.reliability) }
    }
}

/// Contribution-weighted freshness (Section B.8): each signal's freshness is
/// `clamp(1 − age / maxUsefulAge, minimumFreshness, 1)`, averaged with the
/// absolute contribution of the signal's winning-mode votes as weights.
public struct FreshnessCalculator: Sendable {
    public let minimumFreshness: Double
    public let contributionEpsilon: Double

    public init(minimumFreshness: Double = 0.0, contributionEpsilon: Double = 0.0001) {
        self.minimumFreshness = minimumFreshness
        self.contributionEpsilon = contributionEpsilon
    }

    public struct SignalFreshnessInput: Sendable {
        public let contribution: Double
        public let age: TimeInterval
        public let maxUsefulAge: TimeInterval

        public init(contribution: Double, age: TimeInterval, maxUsefulAge: TimeInterval) {
            self.contribution = contribution
            self.age = age
            self.maxUsefulAge = maxUsefulAge
        }
    }

    /// Returns `nil` when nothing materially contributes — freshness is then
    /// unknown, never assumed perfect or zero.
    public func calculate(inputs: [SignalFreshnessInput]) -> Double? {
        let contributing = inputs.filter { abs($0.contribution) > contributionEpsilon && $0.maxUsefulAge > 0 }
        guard !contributing.isEmpty else { return nil }
        let numerator = contributing.reduce(0.0) { partial, input in
            let raw = 1.0 - input.age / input.maxUsefulAge
            let freshness = min(max(raw, minimumFreshness), 1.0)
            return partial + abs(input.contribution) * freshness
        }
        let denominator = contributing.reduce(0.0) { $0 + abs($1.contribution) }
        guard denominator > contributionEpsilon else { return nil }
        return min(max(numerator / denominator, 0.0), 1.0)
    }
}
