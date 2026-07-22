import Foundation

/// One signal-kind → mode vote definition. `nightContextModifier` is the
/// contextual boost applied when the solar phase is night (Section B.7 rule
/// 5: sleep/eye-comfort signals gain priority late at night).
public struct VoteDefinition: Sendable {
    public let mode: AdaptiveMode
    public let baseWeight: Double
    public let nightContextModifier: Double

    public init(mode: AdaptiveMode, baseWeight: Double, nightContextModifier: Double = 1.0) {
        self.mode = mode
        self.baseWeight = baseWeight
        self.nightContextModifier = nightContextModifier
    }
}

/// ALL scoring numbers live here (Section B.5): signal→mode vote weights,
/// per-source reliability defaults, and per-kind freshness useful-ages.
/// Nothing is buried in view models or services.
///
/// Calibration ground truth: with the Section B.6A snapshot (11:24 PM night
/// phase, 68-minute session, explicit low energy, 5 h sleep, positive mood)
/// this table reproduces the worked Eye Comfort votes:
/// lateNight 0.75×1.15, prolongedSession 0.60×1.10, lowEnergy 0.45×1.05,
/// poorSleep 0.40×1.00, positiveValence −0.18×1.00.
public struct AdaptiveScoringConfiguration: Sendable {
    public let voteDefinitions: [ContextSignalKind: [VoteDefinition]]
    public let sourceReliability: [ContextSignalSource: Double]
    public let usefulAges: [ContextSignalKind: TimeInterval]

    public init(
        voteDefinitions: [ContextSignalKind: [VoteDefinition]],
        sourceReliability: [ContextSignalSource: Double],
        usefulAges: [ContextSignalKind: TimeInterval]
    ) {
        self.voteDefinitions = voteDefinitions
        self.sourceReliability = sourceReliability
        self.usefulAges = usefulAges
    }

    public func definitions(for kind: ContextSignalKind) -> [VoteDefinition] {
        voteDefinitions[kind] ?? []
    }

    public func reliability(for source: ContextSignalSource) -> Double {
        sourceReliability[source] ?? 0.5
    }

    public func usefulAge(for kind: ContextSignalKind) -> TimeInterval {
        usefulAges[kind] ?? 60 * 60
    }

    /// Modes the engine may select automatically. `manualCustom` is
    /// user-only by definition.
    public static let automaticCandidates: [AdaptiveMode] =
        AdaptiveMode.allCases.filter { $0 != .manualCustom }

    public static let production = AdaptiveScoringConfiguration(
        voteDefinitions: [
            .lateNight: [
                VoteDefinition(mode: .eyeComfort, baseWeight: 0.75, nightContextModifier: 1.15),
                VoteDefinition(mode: .sleepPreparation, baseWeight: 0.65, nightContextModifier: 1.10),
                VoteDefinition(mode: .energize, baseWeight: -0.40),
            ],
            .earlyMorning: [
                VoteDefinition(mode: .energize, baseWeight: 0.35),
                VoteDefinition(mode: .sleepPreparation, baseWeight: -0.30),
            ],
            .daytime: [
                VoteDefinition(mode: .balanced, baseWeight: 0.15),
            ],
            .solarBrightness: [
                VoteDefinition(mode: .outdoorVisibility, baseWeight: 0.35),
            ],
            .outdoorLikelihood: [
                VoteDefinition(mode: .outdoorVisibility, baseWeight: 0.70),
                VoteDefinition(mode: .eyeComfort, baseWeight: -0.30),
            ],
            .highAmbientVisibility: [
                VoteDefinition(mode: .outdoorVisibility, baseWeight: 0.85),
                VoteDefinition(mode: .eyeComfort, baseWeight: -0.50),
                VoteDefinition(mode: .sleepPreparation, baseWeight: -0.40),
            ],
            .lowAmbientVisibility: [
                VoteDefinition(mode: .eyeComfort, baseWeight: 0.45, nightContextModifier: 1.10),
                VoteDefinition(mode: .outdoorVisibility, baseWeight: -0.50),
            ],
            .poorSleep: [
                VoteDefinition(mode: .recovery, baseWeight: 0.70),
                VoteDefinition(mode: .eyeComfort, baseWeight: 0.40),
                VoteDefinition(mode: .energize, baseWeight: -0.45),
            ],
            .goodSleep: [
                VoteDefinition(mode: .energize, baseWeight: 0.45),
                VoteDefinition(mode: .focus, baseWeight: 0.35),
                VoteDefinition(mode: .recovery, baseWeight: -0.35),
            ],
            .lowEnergy: [
                VoteDefinition(mode: .recovery, baseWeight: 0.55),
                VoteDefinition(mode: .eyeComfort, baseWeight: 0.45, nightContextModifier: 1.05),
                VoteDefinition(mode: .calm, baseWeight: 0.40),
                VoteDefinition(mode: .energize, baseWeight: -0.55),
            ],
            .highEnergy: [
                VoteDefinition(mode: .energize, baseWeight: 0.55),
                VoteDefinition(mode: .focus, baseWeight: 0.35),
            ],
            .negativeValence: [
                VoteDefinition(mode: .calm, baseWeight: 0.55),
                VoteDefinition(mode: .lowStimulation, baseWeight: 0.35),
                VoteDefinition(mode: .energize, baseWeight: -0.30),
            ],
            .positiveValence: [
                VoteDefinition(mode: .energize, baseWeight: 0.30),
                VoteDefinition(mode: .socialConnection, baseWeight: 0.35),
                VoteDefinition(mode: .eyeComfort, baseWeight: -0.18),
                VoteDefinition(mode: .calm, baseWeight: -0.15),
            ],
            .reportedStress: [
                VoteDefinition(mode: .calm, baseWeight: 0.65),
                VoteDefinition(mode: .lowStimulation, baseWeight: 0.45),
                VoteDefinition(mode: .energize, baseWeight: -0.40),
            ],
            .reportedCalm: [
                VoteDefinition(mode: .balanced, baseWeight: 0.25),
            ],
            .interactionFatigue: [
                VoteDefinition(mode: .eyeComfort, baseWeight: 0.50, nightContextModifier: 1.10),
                VoteDefinition(mode: .recovery, baseWeight: 0.40),
                VoteDefinition(mode: .lowStimulation, baseWeight: 0.30),
            ],
            .prolongedSession: [
                VoteDefinition(mode: .eyeComfort, baseWeight: 0.60, nightContextModifier: 1.10),
                VoteDefinition(mode: .recovery, baseWeight: 0.30),
            ],
            .rapidNavigation: [
                VoteDefinition(mode: .focus, baseWeight: 0.30),
                VoteDefinition(mode: .calm, baseWeight: 0.25),
            ],
            .upcomingInterview: [
                VoteDefinition(mode: .interviewPreparation, baseWeight: 0.95),
                VoteDefinition(mode: .calm, baseWeight: -0.20),
            ],
            .activeFocusGoal: [
                VoteDefinition(mode: .focus, baseWeight: 0.80),
                VoteDefinition(mode: .lowStimulation, baseWeight: 0.20),
            ],
            .physicalActivity: [
                VoteDefinition(mode: .energize, baseWeight: 0.35),
            ],
            .inactivity: [
                VoteDefinition(mode: .recovery, baseWeight: 0.20),
            ],
            .rainyWeather: [
                VoteDefinition(mode: .calm, baseWeight: 0.30),
                VoteDefinition(mode: .recovery, baseWeight: 0.20),
            ],
            .pleasantWeather: [
                VoteDefinition(mode: .energize, baseWeight: 0.25),
            ],
            .highUV: [
                VoteDefinition(mode: .outdoorVisibility, baseWeight: 0.40),
            ],
            // Battery/thermal and accessibility kinds intentionally cast NO
            // primary-mode votes — they shape AdaptationModifiers instead
            // (Sections B.13/B.15).
            .thermalPressure: [],
            .lowPowerMode: [],
            .reducedMotionPreference: [],
            .increasedContrastPreference: [],
            .largeTextPreference: [],
            // Manual requests go through the override path, never the vote table.
            .manualModeRequest: [],
        ],
        // Reliability ordering (Section B.4), high → low: explicit user input
        // → direct permissioned measurement → recent in-app behavior →
        // derived environmental context → approximation.
        sourceReliability: [
            .userInput: 1.00,
            .healthKit: 0.90,
            .weatherKit: 0.85,
            .coreLocation: 0.85,
            .coreMotion: 0.80,
            .processInfo: 1.00,
            .systemAccessibility: 1.00,
            .interactionHistory: 0.90,
            .solarModel: 0.95,
            .simulation: 0.95,
        ],
        // Freshness useful-ages (Section B.8 defaults).
        usefulAges: [
            .positiveValence: 4 * 60 * 60,
            .negativeValence: 4 * 60 * 60,
            .reportedStress: 4 * 60 * 60,
            .reportedCalm: 4 * 60 * 60,
            .lowEnergy: 4 * 60 * 60,
            .highEnergy: 4 * 60 * 60,
            .interactionFatigue: 30 * 60,
            .prolongedSession: 30 * 60,
            .rapidNavigation: 30 * 60,
            .rainyWeather: 60 * 60,
            .pleasantWeather: 60 * 60,
            .highUV: 60 * 60,
            .poorSleep: 24 * 60 * 60,
            .goodSleep: 24 * 60 * 60,
            .thermalPressure: 5 * 60,
            .lateNight: 60 * 60,
            .earlyMorning: 60 * 60,
            .daytime: 3 * 60 * 60,
            .solarBrightness: 60 * 60,
            .outdoorLikelihood: 30 * 60,
            .highAmbientVisibility: 30 * 60,
            .lowAmbientVisibility: 30 * 60,
            .upcomingInterview: 3 * 60 * 60,
            .activeFocusGoal: 3 * 60 * 60,
            .physicalActivity: 2 * 60 * 60,
            .inactivity: 2 * 60 * 60,
            .lowPowerMode: 5 * 60,
            .reducedMotionPreference: 24 * 60 * 60,
            .increasedContrastPreference: 24 * 60 * 60,
            .largeTextPreference: 24 * 60 * 60,
            .manualModeRequest: 60 * 60,
        ]
    )
}
