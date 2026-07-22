import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Guards on the centralized scoring configuration (Section B.5): weight
/// ranges, reliability ordering, and the calibration ground truth.
struct ScoringConfigurationTests {
    private let config = AdaptiveScoringConfiguration.production

    @Test
    func allBaseWeightsStayWithinDocumentedRange() {
        for (_, definitions) in config.voteDefinitions {
            for definition in definitions {
                #expect(definition.baseWeight >= -1.0 && definition.baseWeight <= 1.0)
                #expect(definition.nightContextModifier >= 0.5 && definition.nightContextModifier <= 1.5)
            }
        }
    }

    @Test
    func everySignalKindHasAnExplicitTableEntry() {
        // Even modifier-only kinds appear with an explicit empty list — no
        // scoring numbers hide outside this table.
        for kind in ContextSignalKind.allCases {
            #expect(config.voteDefinitions[kind] != nil, "Missing vote table entry for \(kind.rawValue)")
        }
    }

    @Test
    func sourceReliabilityFollowsDocumentedOrdering() {
        // Explicit user input ≥ direct measurement ≥ in-app behavior ≥
        // derived environmental context.
        #expect(config.reliability(for: .userInput) >= config.reliability(for: .healthKit))
        #expect(config.reliability(for: .healthKit) >= config.reliability(for: .interactionHistory))
        #expect(config.reliability(for: .interactionHistory) >= config.reliability(for: .weatherKit))
        for source in ContextSignalSource.allCases {
            let value = config.reliability(for: source)
            #expect(value > 0.0 && value <= 1.0)
        }
    }

    @Test
    func modifierOnlyKindsCastNoPrimaryModeVotes() {
        for kind: ContextSignalKind in [
            .thermalPressure, .lowPowerMode, .reducedMotionPreference,
            .increasedContrastPreference, .largeTextPreference, .manualModeRequest,
        ] {
            #expect(config.definitions(for: kind).isEmpty)
        }
    }

    @Test
    func workedExampleVoteWeightsAreEncodedExactly() throws {
        // Calibration ground truth (B.6A): the Eye Comfort column.
        func weight(_ kind: ContextSignalKind) -> (base: Double, night: Double)? {
            config.definitions(for: kind)
                .first { $0.mode == .eyeComfort }
                .map { ($0.baseWeight, $0.nightContextModifier) }
        }
        let lateNight = try #require(weight(.lateNight))
        #expect(lateNight.base == 0.75 && lateNight.night == 1.15)
        let prolonged = try #require(weight(.prolongedSession))
        #expect(prolonged.base == 0.60 && prolonged.night == 1.10)
        let lowEnergy = try #require(weight(.lowEnergy))
        #expect(lowEnergy.base == 0.45 && lowEnergy.night == 1.05)
        let poorSleep = try #require(weight(.poorSleep))
        #expect(poorSleep.base == 0.40 && poorSleep.night == 1.00)
        let positiveValence = try #require(weight(.positiveValence))
        #expect(positiveValence.base == -0.18 && positiveValence.night == 1.00)
    }

    @Test
    func usefulAgesMatchSectionB8Defaults() {
        #expect(config.usefulAge(for: .positiveValence) == 4 * 60 * 60)   // manual mood 4h
        #expect(config.usefulAge(for: .interactionFatigue) == 30 * 60)     // fatigue 30m
        #expect(config.usefulAge(for: .rainyWeather) == 60 * 60)           // weather 60m
        #expect(config.usefulAge(for: .poorSleep) == 24 * 60 * 60)         // sleep 24h
        #expect(config.usefulAge(for: .thermalPressure) == 5 * 60)         // thermal 5m
    }

    @Test
    func engineConfigurationVariantsShareCalibrationConstants() {
        for variant in [AdaptiveEngineConfiguration.production, .conservative, .demo, .unitTest] {
            #expect(variant.contributionEpsilon == 0.0001)
            #expect(variant.conflictContributionThreshold == 0.10)
            #expect(variant.suggestionConfidence <= variant.automaticAdaptationConfidence)
        }
        // Demo reacts faster but never lowers the automatic bar below production.
        #expect(AdaptiveEngineConfiguration.demo.automaticAdaptationConfidence
                >= AdaptiveEngineConfiguration.production.automaticAdaptationConfidence - 1e-12)
    }
}
