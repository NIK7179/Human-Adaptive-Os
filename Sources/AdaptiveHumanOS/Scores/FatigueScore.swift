import Foundation

// MARK: - Interaction-fatigue score (Section B.17)
//
// Uses ONLY in-app activity. Never typing outside the app, never described
// as neurological or medical fatigue.

public enum InteractionFatigueLevel: String, Codable, Sendable {
    case unavailable, low, moderate, high

    // Low 0.00–0.34, Moderate 0.35–0.64, High 0.65–1.00
    public init(score: Double?) {
        guard let score else {
            self = .unavailable
            return
        }
        switch score {
        case ..<0.35: self = .low
        case ..<0.65: self = .moderate
        default: self = .high
        }
    }
}

public struct FatigueInput: Sendable {
    /// Minutes of continuous in-app session; nil when unknown.
    public let continuousSessionMinutes: Double?
    /// 0.0 ... 1.0 normalized rapid-navigation frequency; nil when unknown.
    public let rapidNavigationRate: Double?
    /// 0.0 ... 1.0 normalized in-app task-switching frequency; nil when unknown.
    public let taskSwitchingRate: Double?
    /// Minutes since the user last took a break; nil when unknown.
    public let minutesSinceLastBreak: Double?
    /// True when the local hour is in the late-night band.
    public let isLateNight: Bool
    /// Explicit, user-reported tiredness 0.0 ... 1.0; nil when not reported.
    public let explicitTiredness: Double?

    public init(
        continuousSessionMinutes: Double?,
        rapidNavigationRate: Double?,
        taskSwitchingRate: Double?,
        minutesSinceLastBreak: Double?,
        isLateNight: Bool,
        explicitTiredness: Double?
    ) {
        self.continuousSessionMinutes = continuousSessionMinutes
        self.rapidNavigationRate = rapidNavigationRate
        self.taskSwitchingRate = taskSwitchingRate
        self.minutesSinceLastBreak = minutesSinceLastBreak
        self.isLateNight = isLateNight
        self.explicitTiredness = explicitTiredness
    }
}

/// fatigueScore = 0.35×session + 0.20×rapidNav + 0.15×taskSwitching
///              + 0.10×timeSinceBreak + 0.10×lateNight + 0.10×explicit
///
/// Cap rule (B.17): the full inferred score is computed FIRST — component
/// weighting, missing-component renormalization, late-night and
/// time-since-break adjustments included — and only then, if no explicit
/// tiredness was reported, capped at 0.75. Explicit tiredness may raise or
/// lower the result afterwards, within 0.0...1.0.
public struct FatigueScoreCalculator: Sendable {
    public let inferredCap: Double

    public init(inferredCap: Double = 0.75) {
        self.inferredCap = inferredCap
    }

    public func calculate(input: FatigueInput) -> Double? {
        struct Component {
            let weight: Double
            let value: Double?
        }
        let components = [
            Component(weight: 0.35, value: input.continuousSessionMinutes.map { min($0 / 120.0, 1.0) }),
            Component(weight: 0.20, value: input.rapidNavigationRate.map { min(max($0, 0.0), 1.0) }),
            Component(weight: 0.15, value: input.taskSwitchingRate.map { min(max($0, 0.0), 1.0) }),
            Component(weight: 0.10, value: input.minutesSinceLastBreak.map { min($0 / 90.0, 1.0) }),
            Component(weight: 0.10, value: input.isLateNight ? 1.0 : 0.0),
        ]
        let available = components.filter { $0.value != nil }
        // At least one behavioral measurement or an explicit report must
        // exist; late-night alone is not a fatigue measurement.
        guard input.continuousSessionMinutes != nil
                || input.rapidNavigationRate != nil
                || input.taskSwitchingRate != nil
                || input.explicitTiredness != nil else {
            return nil
        }

        // Renormalize the inferred components (explicit handled after).
        let inferredWeightTotal = available.reduce(0.0) { $0 + $1.weight }
        var inferred = 0.0
        if inferredWeightTotal > 0 {
            let sum = available.reduce(0.0) { $0 + $1.weight * ($1.value ?? 0.0) }
            inferred = sum / inferredWeightTotal
        }

        if let explicitTiredness = input.explicitTiredness {
            // Explicit tiredness (weight 0.10 in the full formula) blends in
            // after the inferred score, scaled to its share, and lifts the cap.
            let blended = inferred * 0.9 + min(max(explicitTiredness, 0.0), 1.0) * 0.1
            // Strong explicit reports can pull the result toward themselves.
            let adjusted = max(blended, min(explicitTiredness, 1.0) * 0.6 + blended * 0.4)
            return min(max(adjusted, 0.0), 1.0)
        } else {
            // Inferred-only: cap at 0.75.
            return min(max(inferred, 0.0), min(inferredCap, 1.0))
        }
    }

    public func level(input: FatigueInput) -> InteractionFatigueLevel {
        InteractionFatigueLevel(score: calculate(input: input))
    }
}
