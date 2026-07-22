import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Theme composition & modifier precedence (Section B.7A).
struct ThemeComposerTests {
    private let composer = DefaultThemeComposer()
    private let neutralEnvironment = EnvironmentalContext(
        ambientLight: .indoor, likelyOutdoors: false, solarPhase: .afternoon, weather: nil
    )

    @Test
    func increaseContrastOverridesCalmSubtleContrast() {
        let accessibility = AccessibilityContext(
            reduceMotionEnabled: false, increaseContrastEnabled: true,
            largerTextEnabled: false, reduceTransparencyEnabled: false
        )
        let resolved = composer.compose(
            baseTheme: .base(for: .calm), modifiers: .none, accessibility: accessibility,
            environment: neutralEnvironment, powerContext: .nominal, preferences: .default
        )
        #expect(resolved.effective.contrast >= .elevated)
        #expect(resolved.overrides.contains {
            $0.property == .contrast && $0.precedenceLevel == .accessibility
        })
    }

    @Test
    func reduceMotionStripsMotionFromEnergize() {
        let accessibility = AccessibilityContext(
            reduceMotionEnabled: true, increaseContrastEnabled: false,
            largerTextEnabled: false, reduceTransparencyEnabled: false
        )
        let resolved = composer.compose(
            baseTheme: .base(for: .energize), modifiers: .none, accessibility: accessibility,
            environment: neutralEnvironment, powerContext: .nominal, preferences: .default
        )
        #expect(resolved.effective.motion <= .minimal)
    }

    @Test
    func brightSurroundingsRaiseContrastEvenUnderCalm() {
        let bright = EnvironmentalContext(
            ambientLight: .directSunlight, likelyOutdoors: true, solarPhase: .solarNoon, weather: nil
        )
        let resolved = composer.compose(
            baseTheme: .base(for: .calm), modifiers: .none, accessibility: .none,
            environment: bright, powerContext: .nominal, preferences: .default
        )
        #expect(resolved.effective.contrast >= .elevated)
        #expect(resolved.effective.fontWeightAdjustment >= 1)
        #expect(resolved.overrides.contains { $0.precedenceLevel == .environmentalVisibility })
    }

    @Test
    func thermalPressureStripsContinuousAnimationFromAnyMode() {
        let hot = PowerContext(isLowPowerModeEnabled: false, thermalPressure: .serious)
        let resolved = composer.compose(
            baseTheme: .base(for: .energize), modifiers: .none, accessibility: .none,
            environment: neutralEnvironment, powerContext: hot, preferences: .default
        )
        #expect(resolved.effective.motion <= .minimal)
        #expect(resolved.effective.complexity <= .reduced)
        #expect(resolved.overrides.contains { $0.precedenceLevel == .thermalPower })
    }

    @Test
    func reduceTransparencyDisablesMaterials() {
        let accessibility = AccessibilityContext(
            reduceMotionEnabled: false, increaseContrastEnabled: false,
            largerTextEnabled: false, reduceTransparencyEnabled: true
        )
        let resolved = composer.compose(
            baseTheme: .base(for: .balanced), modifiers: .none, accessibility: accessibility,
            environment: neutralEnvironment, powerContext: .nominal, preferences: .default
        )
        #expect(!resolved.effective.usesTranslucentMaterials)
    }

    @Test
    func compositionIsDeterministic() {
        let accessibility = AccessibilityContext(
            reduceMotionEnabled: true, increaseContrastEnabled: true,
            largerTextEnabled: true, reduceTransparencyEnabled: true
        )
        let hot = PowerContext(isLowPowerModeEnabled: true, thermalPressure: .critical)
        let first = composer.compose(
            baseTheme: .base(for: .energize), modifiers: .none, accessibility: accessibility,
            environment: neutralEnvironment, powerContext: hot, preferences: .default
        )
        let second = composer.compose(
            baseTheme: .base(for: .energize), modifiers: .none, accessibility: accessibility,
            environment: neutralEnvironment, powerContext: hot, preferences: .default
        )
        #expect(first == second)
    }

    @Test
    func untouchedThemePassesThroughWithNoOverrideRecords() {
        let resolved = composer.compose(
            baseTheme: .base(for: .balanced), modifiers: .none, accessibility: .none,
            environment: neutralEnvironment, powerContext: .nominal, preferences: .default
        )
        #expect(resolved.effective == resolved.base)
        #expect(resolved.overrides.isEmpty)
    }
}
