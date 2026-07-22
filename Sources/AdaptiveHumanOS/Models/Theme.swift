import Foundation

// MARK: - Semantic theme tokens (Section C.4)
//
// No RGB values here — these are semantic levels the design system maps to
// concrete colors/typography in the UI layer.

public enum BackgroundStyle: String, Codable, CaseIterable, Sendable {
    case neutral, warmDim, warmDark, cool, highContrastLight, highContrastDark, soft
}

public enum ContrastLevel: String, Codable, CaseIterable, Sendable, Comparable {
    case reduced, standard, elevated, maximum

    private var rank: Int {
        switch self {
        case .reduced: return 0
        case .standard: return 1
        case .elevated: return 2
        case .maximum: return 3
        }
    }

    public static func < (lhs: ContrastLevel, rhs: ContrastLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum MotionIntensity: String, Codable, CaseIterable, Sendable, Comparable {
    case none, minimal, gentle, standard, lively

    private var rank: Int {
        switch self {
        case .none: return 0
        case .minimal: return 1
        case .gentle: return 2
        case .standard: return 3
        case .lively: return 4
        }
    }

    public static func < (lhs: MotionIntensity, rhs: MotionIntensity) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum VisualComplexity: String, Codable, CaseIterable, Sendable, Comparable {
    case minimal, reduced, standard, rich

    private var rank: Int {
        switch self {
        case .minimal: return 0
        case .reduced: return 1
        case .standard: return 2
        case .rich: return 3
        }
    }

    public static func < (lhs: VisualComplexity, rhs: VisualComplexity) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum AdjustmentDirection: String, Codable, CaseIterable, Sendable {
    case decrease, neutral, increase
}

/// A mode's base presentation, before constraints are applied.
public struct AdaptiveTheme: Codable, Sendable, Equatable {
    public let mode: AdaptiveMode
    public let background: BackgroundStyle
    public let contrast: ContrastLevel
    public let fontScale: Double                 // multiplier on Dynamic Type, ≥ 1.0 respected
    public let fontWeightAdjustment: Int         // -1 lighter, 0 neutral, +1 heavier
    public let lineSpacingMultiplier: Double
    public let motion: MotionIntensity
    public let animationDurationMultiplier: Double
    public let hapticIntensity: Double           // 0.0 ... 1.0
    public let brightnessDirection: AdjustmentDirection
    public let colorTemperatureDirection: AdjustmentDirection  // increase = warmer
    public let complexity: VisualComplexity
    public let usesTranslucentMaterials: Bool

    public init(
        mode: AdaptiveMode,
        background: BackgroundStyle,
        contrast: ContrastLevel,
        fontScale: Double,
        fontWeightAdjustment: Int,
        lineSpacingMultiplier: Double,
        motion: MotionIntensity,
        animationDurationMultiplier: Double,
        hapticIntensity: Double,
        brightnessDirection: AdjustmentDirection,
        colorTemperatureDirection: AdjustmentDirection,
        complexity: VisualComplexity,
        usesTranslucentMaterials: Bool
    ) {
        self.mode = mode
        self.background = background
        self.contrast = contrast
        self.fontScale = fontScale
        self.fontWeightAdjustment = fontWeightAdjustment
        self.lineSpacingMultiplier = lineSpacingMultiplier
        self.motion = motion
        self.animationDurationMultiplier = animationDurationMultiplier
        self.hapticIntensity = hapticIntensity
        self.brightnessDirection = brightnessDirection
        self.colorTemperatureDirection = colorTemperatureDirection
        self.complexity = complexity
        self.usesTranslucentMaterials = usesTranslucentMaterials
    }

    /// Centralized base-theme catalog. UI maps these to design tokens.
    public static func base(for mode: AdaptiveMode) -> AdaptiveTheme {
        switch mode {
        case .balanced:
            return AdaptiveTheme(
                mode: mode, background: .neutral, contrast: .standard, fontScale: 1.0,
                fontWeightAdjustment: 0, lineSpacingMultiplier: 1.0, motion: .standard,
                animationDurationMultiplier: 1.0, hapticIntensity: 0.6,
                brightnessDirection: .neutral, colorTemperatureDirection: .neutral,
                complexity: .standard, usesTranslucentMaterials: true
            )
        case .calm, .socialConnection:
            return AdaptiveTheme(
                mode: mode, background: .soft, contrast: .standard, fontScale: 1.0,
                fontWeightAdjustment: 0, lineSpacingMultiplier: 1.1, motion: .gentle,
                animationDurationMultiplier: 1.2, hapticIntensity: 0.4,
                brightnessDirection: .decrease, colorTemperatureDirection: .increase,
                complexity: .reduced, usesTranslucentMaterials: true
            )
        case .energize:
            return AdaptiveTheme(
                mode: mode, background: .cool, contrast: .elevated, fontScale: 1.0,
                fontWeightAdjustment: 1, lineSpacingMultiplier: 1.0, motion: .lively,
                animationDurationMultiplier: 0.85, hapticIntensity: 0.8,
                brightnessDirection: .increase, colorTemperatureDirection: .decrease,
                complexity: .rich, usesTranslucentMaterials: true
            )
        case .focus, .interviewPreparation:
            return AdaptiveTheme(
                mode: mode, background: .neutral, contrast: .elevated, fontScale: 1.0,
                fontWeightAdjustment: 0, lineSpacingMultiplier: 1.05, motion: .minimal,
                animationDurationMultiplier: 1.0, hapticIntensity: 0.3,
                brightnessDirection: .neutral, colorTemperatureDirection: .neutral,
                complexity: .reduced, usesTranslucentMaterials: false
            )
        case .recovery:
            return AdaptiveTheme(
                mode: mode, background: .warmDim, contrast: .standard, fontScale: 1.05,
                fontWeightAdjustment: 0, lineSpacingMultiplier: 1.15, motion: .gentle,
                animationDurationMultiplier: 1.3, hapticIntensity: 0.3,
                brightnessDirection: .decrease, colorTemperatureDirection: .increase,
                complexity: .reduced, usesTranslucentMaterials: true
            )
        case .eyeComfort:
            return AdaptiveTheme(
                mode: mode, background: .warmDark, contrast: .standard, fontScale: 1.1,
                fontWeightAdjustment: 0, lineSpacingMultiplier: 1.15, motion: .minimal,
                animationDurationMultiplier: 1.3, hapticIntensity: 0.3,
                brightnessDirection: .decrease, colorTemperatureDirection: .increase,
                complexity: .reduced, usesTranslucentMaterials: false
            )
        case .sleepPreparation, .lowStimulation:
            return AdaptiveTheme(
                mode: mode, background: .warmDark, contrast: .reduced, fontScale: 1.1,
                fontWeightAdjustment: 0, lineSpacingMultiplier: 1.2, motion: .none,
                animationDurationMultiplier: 1.5, hapticIntensity: 0.1,
                brightnessDirection: .decrease, colorTemperatureDirection: .increase,
                complexity: .minimal, usesTranslucentMaterials: false
            )
        case .outdoorVisibility, .commute:
            return AdaptiveTheme(
                mode: mode, background: .highContrastLight, contrast: .maximum, fontScale: 1.1,
                fontWeightAdjustment: 1, lineSpacingMultiplier: 1.0, motion: .minimal,
                animationDurationMultiplier: 0.9, hapticIntensity: 0.7,
                brightnessDirection: .increase, colorTemperatureDirection: .neutral,
                complexity: .minimal, usesTranslucentMaterials: false
            )
        case .manualCustom:
            return AdaptiveTheme(
                mode: mode, background: .neutral, contrast: .standard, fontScale: 1.0,
                fontWeightAdjustment: 0, lineSpacingMultiplier: 1.0, motion: .standard,
                animationDurationMultiplier: 1.0, hapticIntensity: 0.5,
                brightnessDirection: .neutral, colorTemperatureDirection: .neutral,
                complexity: .standard, usesTranslucentMaterials: true
            )
        }
    }
}

// MARK: - Secondary constraints (Section B.7)

public struct AdaptationModifiers: Codable, Sendable, Equatable {
    public let reduceMotion: Bool
    public let increaseContrast: Bool
    public let increaseTextScale: Bool
    public let reduceVisualComplexity: Bool
    public let reduceHaptics: Bool
    public let reduceMediaIntensity: Bool

    public init(
        reduceMotion: Bool = false,
        increaseContrast: Bool = false,
        increaseTextScale: Bool = false,
        reduceVisualComplexity: Bool = false,
        reduceHaptics: Bool = false,
        reduceMediaIntensity: Bool = false
    ) {
        self.reduceMotion = reduceMotion
        self.increaseContrast = increaseContrast
        self.increaseTextScale = increaseTextScale
        self.reduceVisualComplexity = reduceVisualComplexity
        self.reduceHaptics = reduceHaptics
        self.reduceMediaIntensity = reduceMediaIntensity
    }

    public static let none = AdaptationModifiers()
}

// MARK: - Theme composition provenance (Section B.7A)

public enum AdaptiveThemeProperty: String, Codable, CaseIterable, Sendable {
    case background, contrast, fontScale, fontWeight, lineSpacing
    case motion, animationDuration, haptics, brightnessDirection
    case colorTemperature, complexity, translucency
}

/// Precedence, highest → lowest (Section B.7A). Higher-priority constraints
/// must never be weakened by lower-priority preferences.
public enum ThemePrecedenceLevel: Int, Codable, CaseIterable, Sendable, Comparable {
    case platformCapability = 1
    case accessibility = 2
    case safetyReadability = 3
    case environmentalVisibility = 4
    case thermalPower = 5
    case explicitUserOverride = 6
    case lifeMode = 7
    case primaryModeTheme = 8
    case learnedAesthetics = 9
    case decorativeVariation = 10

    public static func < (lhs: ThemePrecedenceLevel, rhs: ThemePrecedenceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ThemeOverrideRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let property: AdaptiveThemeProperty
    public let originalValueDescription: String
    public let resolvedValueDescription: String
    public let precedenceLevel: ThemePrecedenceLevel
    public let reason: String

    public init(
        id: UUID,
        property: AdaptiveThemeProperty,
        originalValueDescription: String,
        resolvedValueDescription: String,
        precedenceLevel: ThemePrecedenceLevel,
        reason: String
    ) {
        self.id = id
        self.property = property
        self.originalValueDescription = originalValueDescription
        self.resolvedValueDescription = resolvedValueDescription
        self.precedenceLevel = precedenceLevel
        self.reason = reason
    }
}

/// The theme after deterministic, precedence-ordered constraint application,
/// with a record of every material override.
public struct ResolvedAdaptiveTheme: Codable, Sendable, Equatable {
    public let base: AdaptiveTheme
    public let effective: AdaptiveTheme
    public let overrides: [ThemeOverrideRecord]

    public init(base: AdaptiveTheme, effective: AdaptiveTheme, overrides: [ThemeOverrideRecord]) {
        self.base = base
        self.effective = effective
        self.overrides = overrides
    }
}
