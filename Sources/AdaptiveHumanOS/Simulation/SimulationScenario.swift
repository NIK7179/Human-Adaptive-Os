import Foundation

/// The ten developer/demo simulation scenarios (Section C.19). Each produces
/// a complete `ContextSnapshot` the engine, dashboard and previews consume.
/// Snapshots are pure functions of the injected reference date.
public enum SimulationScenario: String, Codable, CaseIterable, Sendable, Identifiable {
    case sunnyOutdoorAfternoon
    case rainyLowEnergyEvening
    case lateNightProlongedSession
    case goodSleepProductiveMorning
    case highCognitiveLoad
    case interviewInOneHour
    case recoveryAfterPoorSleep
    case missingPermissions
    case noNetwork
    case manualModeOverride

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sunnyOutdoorAfternoon: return "Sunny outdoor afternoon"
        case .rainyLowEnergyEvening: return "Rainy low-energy evening"
        case .lateNightProlongedSession: return "Late-night prolonged session"
        case .goodSleepProductiveMorning: return "Good-sleep productive morning"
        case .highCognitiveLoad: return "High cognitive load"
        case .interviewInOneHour: return "Interview in one hour"
        case .recoveryAfterPoorSleep: return "Recovery after poor sleep"
        case .missingPermissions: return "Missing permissions"
        case .noNetwork: return "No network"
        case .manualModeOverride: return "Manual mode override"
        }
    }

    /// The mode this scenario is expected to rank first (used by scenario
    /// regression tests and demo copy). `nil` when the point of the scenario
    /// is graceful degradation rather than a particular winner.
    public var expectedLeader: AdaptiveMode? {
        switch self {
        case .sunnyOutdoorAfternoon: return .outdoorVisibility
        case .rainyLowEnergyEvening: return .calm
        case .lateNightProlongedSession: return .eyeComfort
        case .goodSleepProductiveMorning: return .energize
        case .highCognitiveLoad: return .focus
        case .interviewInOneHour: return .interviewPreparation
        case .recoveryAfterPoorSleep: return .recovery
        case .missingPermissions, .noNetwork, .manualModeOverride: return nil
        }
    }

    public func snapshot(at referenceDate: Date) -> ContextSnapshot {
        switch self {
        case .sunnyOutdoorAfternoon:
            return ContextSnapshot(
                timestamp: referenceDate, localHour: 14, dayOfWeek: 3, solarPhase: .afternoon,
                weather: WeatherContext(condition: .clear, temperatureCelsius: 27, isPrecipitating: false, uvIndex: 8),
                likelyOutdoors: true, ambientLight: .directSunlight,
                sleepDurationHours: 7.5, sleepQuality: .good,
                activityLevel: .moderate, stepCount: 6500,
                isSimulated: true
            )
        case .rainyLowEnergyEvening:
            return ContextSnapshot(
                timestamp: referenceDate, localHour: 19, dayOfWeek: 4, solarPhase: .civilTwilightEvening,
                weather: WeatherContext(condition: .rain, temperatureCelsius: 11, isPrecipitating: true, uvIndex: 0),
                likelyOutdoors: false, ambientLight: .dim,
                mood: .low, moodValence: 0.35, moodEnergy: 0.25,
                moodSource: .manualCheckIn, moodReportedAt: referenceDate.addingTimeInterval(-20 * 60),
                sleepDurationHours: 7.0, sleepQuality: .fair,
                activityLevel: .sedentary,
                isSimulated: true
            )
        case .lateNightProlongedSession:
            // The Section B.6A worked example: 11:24 PM, 68-minute session,
            // low energy, 5 h sleep, positive mood, indoors. Ambient stays
            // `.indoor` so exactly the five worked-example signals fire.
            return ContextSnapshot(
                timestamp: referenceDate, localHour: 23, dayOfWeek: 2, solarPhase: .night,
                likelyOutdoors: false, ambientLight: .indoor,
                mood: .positive, moodValence: 0.85, moodEnergy: 0.15,
                moodSource: .manualCheckIn, moodReportedAt: referenceDate.addingTimeInterval(-30 * 60),
                sleepDurationHours: 5.0, sleepQuality: .poor,
                continuousSessionMinutes: 68,
                accessibility: AccessibilityContext(
                    reduceMotionEnabled: true, increaseContrastEnabled: false,
                    largerTextEnabled: false, reduceTransparencyEnabled: false
                ),
                isSimulated: true
            )
        case .goodSleepProductiveMorning:
            return ContextSnapshot(
                timestamp: referenceDate, localHour: 9, dayOfWeek: 2, solarPhase: .morning,
                weather: WeatherContext(condition: .partlyCloudy, temperatureCelsius: 18, isPrecipitating: false, uvIndex: 3),
                likelyOutdoors: false, ambientLight: .indoor,
                mood: .positive, moodValence: 0.75, moodEnergy: 0.8,
                moodSource: .manualCheckIn, moodReportedAt: referenceDate.addingTimeInterval(-10 * 60),
                sleepDurationHours: 8.2, sleepQuality: .excellent,
                activityLevel: .light,
                isSimulated: true
            )
        case .highCognitiveLoad:
            return ContextSnapshot(
                timestamp: referenceDate, localHour: 15, dayOfWeek: 3, solarPhase: .afternoon,
                likelyOutdoors: false, ambientLight: .indoor,
                continuousSessionMinutes: 50, rapidNavigationRate: 0.8,
                minutesSinceLastBreak: 75,
                focusGoal: .deepWork,
                isSimulated: true
            )
        case .interviewInOneHour:
            return ContextSnapshot(
                timestamp: referenceDate, localHour: 10, dayOfWeek: 5, solarPhase: .morning,
                likelyOutdoors: false, ambientLight: .indoor,
                mood: .neutral, moodValence: 0.45, moodEnergy: 0.6,
                moodSource: .manualCheckIn, moodReportedAt: referenceDate.addingTimeInterval(-15 * 60),
                sleepDurationHours: 7.2, sleepQuality: .good,
                focusGoal: .interview, upcomingInterviewMinutes: 60,
                isSimulated: true
            )
        case .recoveryAfterPoorSleep:
            return ContextSnapshot(
                timestamp: referenceDate, localHour: 10, dayOfWeek: 1, solarPhase: .morning,
                likelyOutdoors: false, ambientLight: .indoor,
                mood: .low, moodValence: 0.35, moodEnergy: 0.2,
                moodSource: .manualCheckIn, moodReportedAt: referenceDate.addingTimeInterval(-25 * 60),
                sleepDurationHours: 4.0, sleepQuality: .veryPoor,
                activityLevel: .sedentary,
                isSimulated: true
            )
        case .missingPermissions:
            // No health, weather, or location data at all; solar unavailable.
            return ContextSnapshot(
                timestamp: referenceDate, localHour: 13, dayOfWeek: 3, solarPhase: .unavailable,
                isSimulated: true
            )
        case .noNetwork:
            // Weather absent (network down); everything local still works.
            return ContextSnapshot(
                timestamp: referenceDate, localHour: 17, dayOfWeek: 4, solarPhase: .afternoon,
                likelyOutdoors: false, ambientLight: .indoor,
                sleepDurationHours: 7.0, sleepQuality: .fair,
                continuousSessionMinutes: 25,
                isSimulated: true
            )
        case .manualModeOverride:
            // Calm manually selected while outdoor signals argue otherwise.
            return ContextSnapshot(
                timestamp: referenceDate, localHour: 12, dayOfWeek: 6, solarPhase: .solarNoon,
                weather: WeatherContext(condition: .clear, temperatureCelsius: 24, isPrecipitating: false, uvIndex: 7),
                likelyOutdoors: true, ambientLight: .directSunlight,
                isSimulated: true
            )
        }
    }

    /// A ready-made override for the manual-override scenario.
    public func manualOverride(at referenceDate: Date) -> ManualModeOverride? {
        guard self == .manualModeOverride else { return nil }
        return ManualModeOverride(
            mode: .calm,
            startedAt: referenceDate.addingTimeInterval(-5 * 60),
            expiresAt: referenceDate.addingTimeInterval(55 * 60),
            source: .dashboard
        )
    }
}
