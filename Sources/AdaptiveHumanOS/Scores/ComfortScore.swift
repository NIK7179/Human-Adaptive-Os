import Foundation

// MARK: - Comfort score (Sections B.16 / B.16A)
//
// An ESTIMATED INTERFACE-COMFORT score, never a medical, psychological or
// wellness diagnosis. Missing components renormalize proportionally — they
// are never substituted with zero — and hard safeguards suppress the number
// entirely when the evidence base is too thin.

public enum ComfortFactorKind: String, Codable, CaseIterable, Sendable {
    case explicitRecentFeedback
    case currentModeHistoricalEffectiveness
    case visualAccessibilityAlignment
    case sessionFatigueAlignment
    case environmentalVisibilityAlignment
    case userPreferenceAlignment

    /// Original formula weights (must sum to 1.0).
    public var originalWeight: Double {
        switch self {
        case .explicitRecentFeedback: return 0.30
        case .currentModeHistoricalEffectiveness: return 0.20
        case .visualAccessibilityAlignment: return 0.15
        case .sessionFatigueAlignment: return 0.15
        case .environmentalVisibilityAlignment: return 0.10
        case .userPreferenceAlignment: return 0.10
        }
    }

    public var displayName: String {
        switch self {
        case .explicitRecentFeedback: return "Your recent feedback"
        case .currentModeHistoricalEffectiveness: return "How this mode has worked before"
        case .visualAccessibilityAlignment: return "Visual accessibility alignment"
        case .sessionFatigueAlignment: return "Session fatigue alignment"
        case .environmentalVisibilityAlignment: return "Environmental visibility alignment"
        case .userPreferenceAlignment: return "Preference alignment"
        }
    }
}

public struct ComfortFactorInput: Sendable {
    public let kind: ComfortFactorKind
    /// 0.0 ... 1.0 alignment value.
    public let value: Double
    /// How many observations back this factor (drives reliability caps).
    public let observationCount: Int

    public init(kind: ComfortFactorKind, value: Double, observationCount: Int) {
        self.kind = kind
        self.value = value
        self.observationCount = observationCount
    }
}

public struct ScoreFactor: Codable, Sendable {
    public let name: String
    public let weight: Double
    public let value: Double

    public init(name: String, weight: Double, value: Double) {
        self.name = name
        self.weight = weight
        self.value = value
    }
}

public struct ComfortScoreResult: Codable, Sendable {
    /// 0...100, or nil when there is not enough information.
    public let score: Int?
    public let confidence: Double
    public let contributingFactors: [ScoreFactor]
    public let missingFactors: [String]

    public init(score: Int?, confidence: Double, contributingFactors: [ScoreFactor], missingFactors: [String]) {
        self.score = score
        self.confidence = confidence
        self.contributingFactors = contributingFactors
        self.missingFactors = missingFactors
    }
}

public struct ComfortScoreCalculator: Sendable {
    /// B.16A safeguards.
    public let minimumFactorCount: Int
    public let minimumOriginalWeightCoverage: Double
    public let maximumRenormalizedShare: Double

    public init(
        minimumFactorCount: Int = 3,
        minimumOriginalWeightCoverage: Double = 0.50,
        maximumRenormalizedShare: Double = 0.45
    ) {
        self.minimumFactorCount = minimumFactorCount
        self.minimumOriginalWeightCoverage = minimumOriginalWeightCoverage
        self.maximumRenormalizedShare = maximumRenormalizedShare
    }

    /// Reliability caps for feedback-driven factors (B.16A): 1 obs → 0.35,
    /// 2 → 0.55, 3 → 0.75, 5+ → 1.00.
    public func reliabilityCap(observationCount: Int) -> Double {
        switch observationCount {
        case ..<1: return 0.0
        case 1: return 0.35
        case 2: return 0.55
        case 3, 4: return 0.75
        default: return 1.00
        }
    }

    public func calculate(factors: [ComfortFactorInput]) -> ComfortScoreResult {
        let available = factors.filter { $0.observationCount >= 1 }
        let availableKinds = Set(available.map(\.kind))
        let missing = ComfortFactorKind.allCases
            .filter { !availableKinds.contains($0) }
            .map(\.displayName)

        // Safeguard 1: minimum factor count.
        guard available.count >= minimumFactorCount else {
            return ComfortScoreResult(score: nil, confidence: 0.0, contributingFactors: [], missingFactors: missing)
        }
        // Safeguard 2: minimum original-weight coverage.
        let coverage = available.reduce(0.0) { $0 + $1.kind.originalWeight }
        guard coverage >= minimumOriginalWeightCoverage else {
            return ComfortScoreResult(score: nil, confidence: 0.0, contributingFactors: [], missingFactors: missing)
        }

        // Proportional renormalization of available weights.
        var weights: [ComfortFactorKind: Double] = [:]
        for factor in available {
            weights[factor.kind] = factor.kind.originalWeight / coverage
        }

        // Safeguard 3: cap any single renormalized share at 0.45,
        // redistributing the excess proportionally across uncapped factors.
        for _ in 0..<ComfortFactorKind.allCases.count {
            let over = weights.filter { $0.value > maximumRenormalizedShare + 1e-12 }
            if over.isEmpty { break }
            var excess = 0.0
            for (kind, weight) in over {
                excess += weight - maximumRenormalizedShare
                weights[kind] = maximumRenormalizedShare
            }
            let uncapped = weights.filter { $0.value < maximumRenormalizedShare - 1e-12 }
            let uncappedTotal = uncapped.reduce(0.0) { $0 + $1.value }
            guard uncappedTotal > 1e-12 else {
                // Redistribution impossible → no numeric score.
                return ComfortScoreResult(
                    score: nil, confidence: 0.0, contributingFactors: [], missingFactors: missing
                )
            }
            for (kind, weight) in uncapped {
                weights[kind] = weight + excess * (weight / uncappedTotal)
            }
        }

        // Weighted score with per-factor reliability caps applied to
        // feedback-driven factors.
        var weighted = 0.0
        var contributing: [ScoreFactor] = []
        var reliabilitySum = 0.0
        for factor in available.sorted(by: { $0.kind.rawValue < $1.kind.rawValue }) {
            let weight = weights[factor.kind] ?? 0.0
            let cap = reliabilityCap(observationCount: factor.observationCount)
            let effectiveValue = min(max(factor.value, 0.0), 1.0)
            weighted += weight * effectiveValue
            reliabilitySum += cap
            contributing.append(
                ScoreFactor(name: factor.kind.displayName, weight: weight, value: effectiveValue)
            )
        }

        // Score confidence, computed separately from the score.
        let factorCountFactor = min(Double(available.count) / Double(ComfortFactorKind.allCases.count), 1.0)
        let averageReliability = reliabilitySum / Double(available.count)
        let confidence = min(max(0.4 * factorCountFactor + 0.3 * coverage + 0.3 * averageReliability, 0.0), 1.0)

        // Suppress numeric score under low-confidence conditions.
        let singleWeakSource = available.count == 1
        let allLowReliability = available.allSatisfy { reliabilityCap(observationCount: $0.observationCount) < 0.55 }
        if singleWeakSource || allLowReliability {
            return ComfortScoreResult(
                score: nil, confidence: confidence, contributingFactors: contributing, missingFactors: missing
            )
        }

        let score = Int((weighted * 100.0).rounded())
        return ComfortScoreResult(
            score: min(max(score, 0), 100),
            confidence: confidence,
            contributingFactors: contributing,
            missingFactors: missing
        )
    }
}
