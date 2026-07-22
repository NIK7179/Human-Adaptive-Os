import Foundation

// MARK: - Supporting context enums (Section C.5)

public enum MoodState: String, Codable, CaseIterable, Sendable {
    case veryLow, low, neutral, positive, veryPositive
}

public enum MoodSource: String, Codable, Sendable {
    case manualCheckIn, healthKitStateOfMind, interactionEstimate, unavailable
}

public enum SleepQuality: String, Codable, CaseIterable, Sendable {
    case veryPoor, poor, fair, good, excellent
}

public enum AmbientLightCategory: String, Codable, CaseIterable, Sendable {
    case veryDark, dim, indoor, bright, directSunlight
}

public enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case sedentary, light, moderate, vigorous
}

public enum FocusGoal: String, Codable, CaseIterable, Sendable {
    case none, deepWork, study, interview, reading, unwinding
}

public enum WeatherCondition: String, Codable, CaseIterable, Sendable {
    case clear, partlyCloudy, overcast, rain, snow, storm, fog, unknown
}

public struct WeatherContext: Codable, Sendable {
    public let condition: WeatherCondition
    public let temperatureCelsius: Double?
    public let isPrecipitating: Bool
    public let uvIndex: Int?

    public init(condition: WeatherCondition, temperatureCelsius: Double?, isPrecipitating: Bool, uvIndex: Int?) {
        self.condition = condition
        self.temperatureCelsius = temperatureCelsius
        self.isPrecipitating = isPrecipitating
        self.uvIndex = uvIndex
    }
}

/// Section B.14. When sunrise/sunset does not occur on the date, the solar
/// model reports `polarDay`/`polarNight` — it never fabricates sun events.
public enum SolarPhase: String, Codable, CaseIterable, Sendable {
    case night, civilTwilightMorning, morning, solarNoon, afternoon, civilTwilightEvening
    case polarDay, polarNight, unavailable
}

public enum ThermalPressureLevel: String, Codable, CaseIterable, Sendable {
    case nominal, fair, serious, critical
}

/// Battery/thermal constraints (Section B.15). These usually shape
/// `AdaptationModifiers`, not the primary mode.
public struct PowerContext: Codable, Sendable {
    public let isLowPowerModeEnabled: Bool
    public let thermalPressure: ThermalPressureLevel

    public init(isLowPowerModeEnabled: Bool, thermalPressure: ThermalPressureLevel) {
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.thermalPressure = thermalPressure
    }

    public static let nominal = PowerContext(isLowPowerModeEnabled: false, thermalPressure: .nominal)
}

/// System accessibility settings read as *constraints*, never as mood
/// indicators (Section B.13).
public struct AccessibilityContext: Codable, Sendable {
    public let reduceMotionEnabled: Bool
    public let increaseContrastEnabled: Bool
    public let largerTextEnabled: Bool
    public let reduceTransparencyEnabled: Bool

    public init(
        reduceMotionEnabled: Bool,
        increaseContrastEnabled: Bool,
        largerTextEnabled: Bool,
        reduceTransparencyEnabled: Bool
    ) {
        self.reduceMotionEnabled = reduceMotionEnabled
        self.increaseContrastEnabled = increaseContrastEnabled
        self.largerTextEnabled = largerTextEnabled
        self.reduceTransparencyEnabled = reduceTransparencyEnabled
    }

    public static let none = AccessibilityContext(
        reduceMotionEnabled: false,
        increaseContrastEnabled: false,
        largerTextEnabled: false,
        reduceTransparencyEnabled: false
    )
}

public struct EnvironmentalContext: Codable, Sendable {
    public let ambientLight: AmbientLightCategory?
    public let likelyOutdoors: Bool?
    public let solarPhase: SolarPhase
    public let weather: WeatherContext?

    public init(
        ambientLight: AmbientLightCategory?,
        likelyOutdoors: Bool?,
        solarPhase: SolarPhase,
        weather: WeatherContext?
    ) {
        self.ambientLight = ambientLight
        self.likelyOutdoors = likelyOutdoors
        self.solarPhase = solarPhase
        self.weather = weather
    }
}

// MARK: - Context snapshot

/// Everything the engine may evaluate, captured at one instant. Missing data
/// is expressed as `nil` — never as a zero measurement (Section B.3).
public struct ContextSnapshot: Codable, Sendable {
    public let timestamp: Date
    public let localHour: Int
    public let dayOfWeek: Int
    public let solarPhase: SolarPhase
    public let weather: WeatherContext?
    public let likelyOutdoors: Bool?
    public let ambientLight: AmbientLightCategory?
    public let mood: MoodState?
    public let moodValence: Double?          // 0.0 (very negative) ... 1.0 (very positive)
    public let moodEnergy: Double?           // 0.0 (drained) ... 1.0 (energized)
    public let moodSource: MoodSource
    public let moodReportedAt: Date?
    public let sleepDurationHours: Double?
    public let sleepQuality: SleepQuality?
    public let activityLevel: ActivityLevel?
    public let stepCount: Int?
    public let continuousSessionMinutes: Double?
    public let rapidNavigationRate: Double?  // 0.0 ... 1.0 normalized
    public let minutesSinceLastBreak: Double?
    public let explicitTiredness: Double?    // 0.0 ... 1.0, user-reported
    public let focusGoal: FocusGoal
    public let upcomingInterviewMinutes: Double?
    public let accessibility: AccessibilityContext
    public let power: PowerContext
    public let isSimulated: Bool

    public init(
        timestamp: Date,
        localHour: Int,
        dayOfWeek: Int,
        solarPhase: SolarPhase,
        weather: WeatherContext? = nil,
        likelyOutdoors: Bool? = nil,
        ambientLight: AmbientLightCategory? = nil,
        mood: MoodState? = nil,
        moodValence: Double? = nil,
        moodEnergy: Double? = nil,
        moodSource: MoodSource = .unavailable,
        moodReportedAt: Date? = nil,
        sleepDurationHours: Double? = nil,
        sleepQuality: SleepQuality? = nil,
        activityLevel: ActivityLevel? = nil,
        stepCount: Int? = nil,
        continuousSessionMinutes: Double? = nil,
        rapidNavigationRate: Double? = nil,
        minutesSinceLastBreak: Double? = nil,
        explicitTiredness: Double? = nil,
        focusGoal: FocusGoal = .none,
        upcomingInterviewMinutes: Double? = nil,
        accessibility: AccessibilityContext = .none,
        power: PowerContext = .nominal,
        isSimulated: Bool = false
    ) {
        self.timestamp = timestamp
        self.localHour = localHour
        self.dayOfWeek = dayOfWeek
        self.solarPhase = solarPhase
        self.weather = weather
        self.likelyOutdoors = likelyOutdoors
        self.ambientLight = ambientLight
        self.mood = mood
        self.moodValence = moodValence
        self.moodEnergy = moodEnergy
        self.moodSource = moodSource
        self.moodReportedAt = moodReportedAt
        self.sleepDurationHours = sleepDurationHours
        self.sleepQuality = sleepQuality
        self.activityLevel = activityLevel
        self.stepCount = stepCount
        self.continuousSessionMinutes = continuousSessionMinutes
        self.rapidNavigationRate = rapidNavigationRate
        self.minutesSinceLastBreak = minutesSinceLastBreak
        self.explicitTiredness = explicitTiredness
        self.focusGoal = focusGoal
        self.upcomingInterviewMinutes = upcomingInterviewMinutes
        self.accessibility = accessibility
        self.power = power
        self.isSimulated = isSimulated
    }

    public var environment: EnvironmentalContext {
        EnvironmentalContext(
            ambientLight: ambientLight,
            likelyOutdoors: likelyOutdoors,
            solarPhase: solarPhase,
            weather: weather
        )
    }
}
