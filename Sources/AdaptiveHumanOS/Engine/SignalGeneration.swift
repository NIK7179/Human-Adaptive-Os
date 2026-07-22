import Foundation

/// Deterministically derives `ContextSignal`s from a `ContextSnapshot`
/// (pipeline stages 1–3). Missing snapshot fields generate NO signal —
/// absence is never converted to a zero-valued measurement (Section B.3).
///
/// Signal strengths are calibrated against the Section B.6A worked example:
/// 11:24 PM → lateNight 0.90; 68-minute session → prolongedSession 0.80;
/// explicit energy 0.15 → lowEnergy 0.85; 5 h sleep → poorSleep 0.75;
/// valence 0.85 → positiveValence 0.70.
public struct ContextSignalGenerator: Sendable {
    public let configuration: AdaptiveScoringConfiguration
    public let idGenerator: any AdaptiveIDGenerating

    public init(configuration: AdaptiveScoringConfiguration, idGenerator: any AdaptiveIDGenerating) {
        self.configuration = configuration
        self.idGenerator = idGenerator
    }

    public func signals(from snapshot: ContextSnapshot) async -> [ContextSignal] {
        var signals: [ContextSignal] = []

        func add(
            _ kind: ContextSignalKind,
            strength: Double,
            source: ContextSignalSource,
            timestamp: Date? = nil,
            isApproximation: Bool = false,
            reliabilityOverride: Double? = nil,
            explanation: String
        ) async {
            let clamped = min(max(strength, 0.0), 1.0)
            let observedAt = timestamp ?? snapshot.timestamp
            let baseReliability = reliabilityOverride ?? configuration.reliability(for: source)
            // Approximations are always less reliable than direct measurement.
            let reliability = isApproximation ? baseReliability * 0.75 : baseReliability
            let usefulAge = configuration.usefulAge(for: kind)
            signals.append(
                ContextSignal(
                    id: await idGenerator.makeID(),
                    kind: kind,
                    normalizedValue: clamped,
                    reliability: reliability,
                    source: snapshot.isSimulated ? .simulation : source,
                    timestamp: observedAt,
                    expiresAt: observedAt.addingTimeInterval(usefulAge * 2),
                    isApproximation: isApproximation,
                    explanation: explanation
                )
            )
        }

        // Time of day / solar phase.
        switch snapshot.solarPhase {
        case .night, .polarNight:
            if snapshot.localHour >= 22 || snapshot.localHour < 5 {
                let strength: Double
                switch snapshot.localHour {
                case 22: strength = 0.80
                case 23: strength = 0.90
                default: strength = 1.00
                }
                await add(
                    .lateNight, strength: strength, source: .solarModel,
                    explanation: snapshot.solarPhase == .polarNight
                        ? "It is late during polar night — the sun does not rise today."
                        : "It is late at night, well after sunset."
                )
            }
        case .civilTwilightMorning:
            await add(.earlyMorning, strength: 0.8, source: .solarModel,
                      explanation: "It is early morning, around first light.")
        case .morning, .solarNoon, .afternoon, .polarDay:
            await add(.daytime, strength: 0.7, source: .solarModel,
                      explanation: snapshot.solarPhase == .polarDay
                          ? "Polar day — the sun stays up; treating as daytime."
                          : "It is daytime.")
        case .civilTwilightEvening:
            break
        case .unavailable:
            // Solar model unavailable → clearly-identified time approximation.
            if snapshot.localHour >= 22 || snapshot.localHour < 5 {
                await add(.lateNight, strength: 0.8, source: .solarModel, isApproximation: true,
                          explanation: "Based on the clock only (location unavailable), it is late at night.")
            } else if snapshot.localHour >= 9 && snapshot.localHour < 18 {
                await add(.daytime, strength: 0.6, source: .solarModel, isApproximation: true,
                          explanation: "Based on the clock only (location unavailable), it is daytime.")
            }
        }

        // Solar brightness: the sun is high and the user is plausibly in it.
        let sunIsUp = snapshot.solarPhase == .morning || snapshot.solarPhase == .solarNoon
            || snapshot.solarPhase == .afternoon || snapshot.solarPhase == .polarDay
        if sunIsUp, snapshot.likelyOutdoors == true || snapshot.ambientLight == .directSunlight {
            await add(.solarBrightness,
                      strength: snapshot.solarPhase == .solarNoon ? 0.9 : 0.8,
                      source: .solarModel,
                      explanation: "The sun is up and you appear to be in it.")
        }

        // Ambient visibility / outdoor likelihood.
        if let ambient = snapshot.ambientLight {
            switch ambient {
            case .directSunlight:
                await add(.highAmbientVisibility, strength: 1.0, source: .coreLocation, isApproximation: true,
                          explanation: "Surroundings appear to be in direct sunlight.")
            case .bright:
                await add(.highAmbientVisibility, strength: 0.7, source: .coreLocation, isApproximation: true,
                          explanation: "Surroundings appear bright.")
            case .veryDark:
                await add(.lowAmbientVisibility, strength: 0.9, source: .coreLocation, isApproximation: true,
                          explanation: "Surroundings appear very dark.")
            case .dim:
                await add(.lowAmbientVisibility, strength: 0.6, source: .coreLocation, isApproximation: true,
                          explanation: "Surroundings appear dim.")
            case .indoor:
                break
            }
        }
        if snapshot.likelyOutdoors == true {
            await add(.outdoorLikelihood, strength: 0.8, source: .coreMotion, isApproximation: true,
                      explanation: "You are likely outdoors right now.")
        }

        // Sleep.
        if let hours = snapshot.sleepDurationHours {
            if hours < 7.0 {
                await add(.poorSleep, strength: (8.0 - hours) / 4.0, source: .healthKit,
                          explanation: String(format: "About %.1f hours of sleep last night.", hours))
            } else if hours >= 7.0 {
                await add(.goodSleep, strength: min((hours - 6.0) / 3.0, 1.0), source: .healthKit,
                          explanation: String(format: "A solid %.1f hours of sleep last night.", hours))
            }
        }

        // Mood — only explicit or permissioned sources ever reach the
        // snapshot (Section C.6); the generator never infers emotion. An
        // opt-in interaction estimate is an approximation with lower
        // reliability than an explicit report — never labeled as user input.
        let moodSource: ContextSignalSource
        let moodIsApproximation: Bool
        switch snapshot.moodSource {
        case .healthKitStateOfMind:
            moodSource = .healthKit
            moodIsApproximation = false
        case .interactionEstimate:
            moodSource = .interactionHistory
            moodIsApproximation = true
        case .manualCheckIn, .unavailable:
            moodSource = .userInput
            moodIsApproximation = false
        }
        if let valence = snapshot.moodValence {
            let reportedAt = snapshot.moodReportedAt ?? snapshot.timestamp
            if valence > 0.5 {
                await add(.positiveValence, strength: (valence - 0.5) * 2.0, source: moodSource,
                          timestamp: reportedAt, isApproximation: moodIsApproximation,
                          explanation: moodIsApproximation
                              ? "In-app activity loosely suggests a positive mood (estimate)."
                              : "You reported a positive mood.")
            } else if valence < 0.5 {
                await add(.negativeValence, strength: (0.5 - valence) * 2.0, source: moodSource,
                          timestamp: reportedAt, isApproximation: moodIsApproximation,
                          explanation: moodIsApproximation
                              ? "In-app activity loosely suggests a difficult mood (estimate)."
                              : "You reported a difficult mood.")
            }
        }
        if let energy = snapshot.moodEnergy {
            let reportedAt = snapshot.moodReportedAt ?? snapshot.timestamp
            if energy < 0.5 {
                await add(.lowEnergy, strength: 1.0 - energy, source: moodSource,
                          timestamp: reportedAt, isApproximation: moodIsApproximation,
                          explanation: moodIsApproximation
                              ? "In-app activity loosely suggests low energy (estimate)."
                              : "You reported low energy.")
            } else if energy > 0.6 {
                await add(.highEnergy, strength: energy, source: moodSource,
                          timestamp: reportedAt, isApproximation: moodIsApproximation,
                          explanation: moodIsApproximation
                              ? "In-app activity loosely suggests high energy (estimate)."
                              : "You reported high energy.")
            }
        }

        // In-app interaction (never other apps — Section C.7).
        if let minutes = snapshot.continuousSessionMinutes, minutes >= 20 {
            await add(.prolongedSession, strength: minutes / 85.0, source: .interactionHistory,
                      explanation: String(format: "Continuous %.0f-minute session.", minutes))
        }
        if let rate = snapshot.rapidNavigationRate, rate > 0.3 {
            await add(.rapidNavigation, strength: rate, source: .interactionHistory,
                      explanation: "Navigation has been unusually rapid.")
        }

        // Goals.
        if let interviewMinutes = snapshot.upcomingInterviewMinutes, interviewMinutes <= 120 {
            await add(.upcomingInterview, strength: 1.0 - (interviewMinutes / 240.0), source: .userInput,
                      explanation: String(format: "Interview coming up in %.0f minutes.", interviewMinutes))
        }
        switch snapshot.focusGoal {
        case .deepWork, .study, .reading:
            await add(.activeFocusGoal, strength: 0.9, source: .userInput,
                      explanation: "You set an active focus goal.")
        case .interview, .none, .unwinding:
            break
        }

        // Activity.
        if let activity = snapshot.activityLevel {
            switch activity {
            case .vigorous:
                await add(.physicalActivity, strength: 0.9, source: .healthKit,
                          explanation: "You have been very active.")
            case .moderate:
                await add(.physicalActivity, strength: 0.6, source: .healthKit,
                          explanation: "You have been moderately active.")
            case .sedentary:
                await add(.inactivity, strength: 0.6, source: .healthKit,
                          explanation: "Little movement recorded recently.")
            case .light:
                break
            }
        }

        // Weather.
        if let weather = snapshot.weather {
            if weather.isPrecipitating || weather.condition == .rain || weather.condition == .storm {
                await add(.rainyWeather, strength: 0.8, source: .weatherKit,
                          explanation: "It is raining nearby.")
            } else if weather.condition == .clear || weather.condition == .partlyCloudy {
                await add(.pleasantWeather, strength: 0.6, source: .weatherKit,
                          explanation: "Pleasant weather outside.")
            }
            if let uv = weather.uvIndex, uv >= 6 {
                await add(.highUV, strength: min(Double(uv) / 10.0, 1.0), source: .weatherKit,
                          explanation: "High UV levels outside.")
            }
        }

        // Power & thermal (modifier-shaping signals; no primary-mode votes).
        if snapshot.power.isLowPowerModeEnabled {
            await add(.lowPowerMode, strength: 1.0, source: .processInfo,
                      explanation: "Low Power Mode is on.")
        }
        switch snapshot.power.thermalPressure {
        case .serious:
            await add(.thermalPressure, strength: 0.7, source: .processInfo,
                      explanation: "The device is running warm.")
        case .critical:
            await add(.thermalPressure, strength: 1.0, source: .processInfo,
                      explanation: "The device is running hot.")
        case .nominal, .fair:
            break
        }

        // Accessibility (constraints, never mood indicators — Section B.13).
        if snapshot.accessibility.reduceMotionEnabled {
            await add(.reducedMotionPreference, strength: 1.0, source: .systemAccessibility,
                      explanation: "Reduce Motion is enabled in system settings.")
        }
        if snapshot.accessibility.increaseContrastEnabled {
            await add(.increasedContrastPreference, strength: 1.0, source: .systemAccessibility,
                      explanation: "Increase Contrast is enabled in system settings.")
        }
        if snapshot.accessibility.largerTextEnabled {
            await add(.largeTextPreference, strength: 1.0, source: .systemAccessibility,
                      explanation: "Larger text sizes are enabled in system settings.")
        }

        return signals
    }
}
