import Foundation

public protocol AdaptiveThemeComposing: Sendable {
    func compose(
        baseTheme: AdaptiveTheme,
        modifiers: AdaptationModifiers,
        accessibility: AccessibilityContext,
        environment: EnvironmentalContext,
        powerContext: PowerContext,
        preferences: AdaptivePreferences
    ) -> ResolvedAdaptiveTheme
}

/// Deterministic, precedence-ordered theme composition (Section B.7A).
/// Constraints apply from LOWEST precedence to HIGHEST so that
/// higher-priority stages always land last and can never be weakened by
/// lower-priority preferences. Every material change is recorded.
///
/// Override-record IDs derive deterministically from the property being
/// overridden, so composition is a pure function of its inputs.
public struct DefaultThemeComposer: AdaptiveThemeComposing {
    public init() {}

    public func compose(
        baseTheme: AdaptiveTheme,
        modifiers: AdaptationModifiers,
        accessibility: AccessibilityContext,
        environment: EnvironmentalContext,
        powerContext: PowerContext,
        preferences: AdaptivePreferences
    ) -> ResolvedAdaptiveTheme {
        var working = MutableTheme(theme: baseTheme)
        var records: [ThemeOverrideRecord] = []

        func record(
            _ property: AdaptiveThemeProperty,
            from original: String,
            to resolved: String,
            level: ThemePrecedenceLevel,
            reason: String
        ) {
            guard original != resolved else { return }
            records.append(
                ThemeOverrideRecord(
                    id: deterministicID(property: property, level: level),
                    property: property,
                    originalValueDescription: original,
                    resolvedValueDescription: resolved,
                    precedenceLevel: level,
                    reason: reason
                )
            )
        }

        // (9→8) Learned aesthetics / user reduced-stimulation preference.
        if preferences.reducedStimulationPreferred, working.complexity > .reduced {
            record(.complexity, from: working.complexity.rawValue, to: VisualComplexity.reduced.rawValue,
                   level: .learnedAesthetics, reason: "You prefer reduced stimulation.")
            working.complexity = .reduced
        }

        // (6) Explicit current-user modifiers from the decision.
        if modifiers.reduceVisualComplexity, working.complexity > .reduced {
            record(.complexity, from: working.complexity.rawValue, to: VisualComplexity.reduced.rawValue,
                   level: .explicitUserOverride, reason: "Visual complexity reduced for this adaptation.")
            working.complexity = .reduced
        }
        if modifiers.reduceHaptics, working.hapticIntensity > 0.3 {
            record(.haptics, from: describe(working.hapticIntensity), to: describe(0.3),
                   level: .explicitUserOverride, reason: "Haptics reduced for this adaptation.")
            working.hapticIntensity = 0.3
        }
        if modifiers.increaseTextScale, working.fontScale < 1.1 {
            record(.fontScale, from: describe(working.fontScale), to: describe(1.1),
                   level: .explicitUserOverride, reason: "Text scale raised for this adaptation.")
            working.fontScale = 1.1
        }

        // (5) Thermal / Low Power: strip continuous animation from ANY mode.
        if powerContext.thermalPressure == .serious || powerContext.thermalPressure == .critical {
            if working.motion > .minimal {
                record(.motion, from: working.motion.rawValue, to: MotionIntensity.minimal.rawValue,
                       level: .thermalPower, reason: "The device is warm, so continuous animation is paused.")
                working.motion = .minimal
            }
            if working.complexity > .reduced {
                record(.complexity, from: working.complexity.rawValue, to: VisualComplexity.reduced.rawValue,
                       level: .thermalPower, reason: "Visual complexity lowered while the device is warm.")
                working.complexity = .reduced
            }
        }
        if powerContext.isLowPowerModeEnabled, working.motion > .gentle {
            record(.motion, from: working.motion.rawValue, to: MotionIntensity.gentle.rawValue,
                   level: .thermalPower, reason: "Low Power Mode is on, so motion is reduced.")
            working.motion = .gentle
        }

        // (4) Environmental visibility: bright surroundings may raise
        // contrast and weight even under Calm.
        if environment.ambientLight == .directSunlight || environment.ambientLight == .bright {
            if working.contrast < .elevated {
                record(.contrast, from: working.contrast.rawValue, to: ContrastLevel.elevated.rawValue,
                       level: .environmentalVisibility, reason: "Bright surroundings need stronger contrast.")
                working.contrast = .elevated
            }
            if working.fontWeightAdjustment < 1 {
                record(.fontWeight, from: "\(working.fontWeightAdjustment)", to: "1",
                       level: .environmentalVisibility, reason: "Heavier text stays readable in bright light.")
                working.fontWeightAdjustment = 1
            }
        }

        // (2) Accessibility: mandatory, may restrict any theme.
        if accessibility.reduceMotionEnabled, working.motion > .minimal {
            record(.motion, from: working.motion.rawValue, to: MotionIntensity.minimal.rawValue,
                   level: .accessibility, reason: "Reduce Motion is enabled in system settings.")
            working.motion = .minimal
        }
        if accessibility.increaseContrastEnabled, working.contrast < .elevated {
            record(.contrast, from: working.contrast.rawValue, to: ContrastLevel.elevated.rawValue,
                   level: .accessibility, reason: "Increase Contrast is enabled in system settings.")
            working.contrast = .elevated
        }
        if accessibility.largerTextEnabled, working.fontScale < 1.0 {
            // Never reduce below the system preference (Dynamic Type is respected in UI).
            record(.fontScale, from: describe(working.fontScale), to: describe(1.0),
                   level: .accessibility, reason: "Text never shrinks below your system preference.")
            working.fontScale = 1.0
        }
        if accessibility.reduceTransparencyEnabled, working.usesTranslucentMaterials {
            record(.translucency, from: "translucent", to: "opaque",
                   level: .accessibility, reason: "Reduce Transparency is enabled in system settings.")
            working.usesTranslucentMaterials = false
        }
        if modifiers.increaseContrast, working.contrast < .elevated {
            record(.contrast, from: working.contrast.rawValue, to: ContrastLevel.elevated.rawValue,
                   level: .accessibility, reason: "Contrast raised for readability.")
            working.contrast = .elevated
        }
        if modifiers.reduceMotion, working.motion > .minimal {
            record(.motion, from: working.motion.rawValue, to: MotionIntensity.minimal.rawValue,
                   level: .accessibility, reason: "Motion reduced for this adaptation.")
            working.motion = .minimal
        }

        let overrides = records.sorted { lhs, rhs in
            if lhs.precedenceLevel != rhs.precedenceLevel {
                return lhs.precedenceLevel < rhs.precedenceLevel
            }
            return lhs.property.rawValue < rhs.property.rawValue
        }
        return ResolvedAdaptiveTheme(
            base: baseTheme,
            effective: working.snapshot(mode: baseTheme.mode),
            overrides: overrides
        )
    }

    private func describe(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Stable ID from property + precedence level bytes; keeps composition a
    /// pure function without an injected ID generator.
    private func deterministicID(property: AdaptiveThemeProperty, level: ThemePrecedenceLevel) -> UUID {
        let propertyIndex = UInt8(AdaptiveThemeProperty.allCases.firstIndex(of: property) ?? 0)
        let levelIndex = UInt8(level.rawValue)
        return UUID(uuid: (0xAD, 0xA9, 0x7E, 0x00, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, propertyIndex, levelIndex))
    }
}

/// Internal mutable working copy used during composition.
private struct MutableTheme {
    var background: BackgroundStyle
    var contrast: ContrastLevel
    var fontScale: Double
    var fontWeightAdjustment: Int
    var lineSpacingMultiplier: Double
    var motion: MotionIntensity
    var animationDurationMultiplier: Double
    var hapticIntensity: Double
    var brightnessDirection: AdjustmentDirection
    var colorTemperatureDirection: AdjustmentDirection
    var complexity: VisualComplexity
    var usesTranslucentMaterials: Bool

    init(theme: AdaptiveTheme) {
        background = theme.background
        contrast = theme.contrast
        fontScale = theme.fontScale
        fontWeightAdjustment = theme.fontWeightAdjustment
        lineSpacingMultiplier = theme.lineSpacingMultiplier
        motion = theme.motion
        animationDurationMultiplier = theme.animationDurationMultiplier
        hapticIntensity = theme.hapticIntensity
        brightnessDirection = theme.brightnessDirection
        colorTemperatureDirection = theme.colorTemperatureDirection
        complexity = theme.complexity
        usesTranslucentMaterials = theme.usesTranslucentMaterials
    }

    func snapshot(mode: AdaptiveMode) -> AdaptiveTheme {
        AdaptiveTheme(
            mode: mode,
            background: background,
            contrast: contrast,
            fontScale: fontScale,
            fontWeightAdjustment: fontWeightAdjustment,
            lineSpacingMultiplier: lineSpacingMultiplier,
            motion: motion,
            animationDurationMultiplier: animationDurationMultiplier,
            hapticIntensity: hapticIntensity,
            brightnessDirection: brightnessDirection,
            colorTemperatureDirection: colorTemperatureDirection,
            complexity: complexity,
            usesTranslucentMaterials: usesTranslucentMaterials
        )
    }
}
