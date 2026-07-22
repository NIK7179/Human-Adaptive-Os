import Foundation
import AdaptiveHumanOS

// MARK: - AdaptiveExperienceKit (Section C.17)
//
// A CONCEPT SDK showing how a participating app could VOLUNTARILY adopt the
// user's current adaptive context. It never performs runtime injection or
// modification of unrelated apps — a partner app links this package, reads
// the published theme, and applies it to its own views.

/// The context a partner app receives — deliberately minimal: no health
/// data, no mood values, no location. Just presentation intent.
public struct AdaptiveExperienceContext: Codable, Sendable, Equatable {
    public let mode: AdaptiveMode
    public let theme: AdaptiveExperienceTheme
    public let isSimulated: Bool

    public init(mode: AdaptiveMode, theme: AdaptiveExperienceTheme, isSimulated: Bool) {
        self.mode = mode
        self.theme = theme
        self.isSimulated = isSimulated
    }
}

/// Presentation contract a partner adopts: colors, typography, spacing,
/// motion, complexity, media intensity, content density.
public struct AdaptiveExperienceTheme: Codable, Sendable, Equatable {
    public let background: BackgroundStyle
    public let contrast: ContrastLevel
    public let fontScale: Double
    public let lineSpacingMultiplier: Double
    public let motion: MotionIntensity
    public let animationDurationMultiplier: Double
    public let complexity: VisualComplexity
    /// 0.0 ... 1.0 — partner apps damp autoplaying/vivid media accordingly.
    public let mediaIntensity: Double
    /// 0.0 ... 1.0 — how densely a partner should pack content.
    public let contentDensity: Double

    public init(
        background: BackgroundStyle,
        contrast: ContrastLevel,
        fontScale: Double,
        lineSpacingMultiplier: Double,
        motion: MotionIntensity,
        animationDurationMultiplier: Double,
        complexity: VisualComplexity,
        mediaIntensity: Double,
        contentDensity: Double
    ) {
        self.background = background
        self.contrast = contrast
        self.fontScale = fontScale
        self.lineSpacingMultiplier = lineSpacingMultiplier
        self.motion = motion
        self.animationDurationMultiplier = animationDurationMultiplier
        self.complexity = complexity
        self.mediaIntensity = mediaIntensity
        self.contentDensity = contentDensity
    }

    /// Bridges the host app's resolved theme into the partner contract.
    public init(from theme: AdaptiveTheme) {
        self.background = theme.background
        self.contrast = theme.contrast
        self.fontScale = theme.fontScale
        self.lineSpacingMultiplier = theme.lineSpacingMultiplier
        self.motion = theme.motion
        self.animationDurationMultiplier = theme.animationDurationMultiplier
        self.complexity = theme.complexity
        switch theme.complexity {
        case .minimal: self.mediaIntensity = 0.2; self.contentDensity = 0.4
        case .reduced: self.mediaIntensity = 0.5; self.contentDensity = 0.6
        case .standard: self.mediaIntensity = 0.8; self.contentDensity = 0.8
        case .rich: self.mediaIntensity = 1.0; self.contentDensity = 1.0
        }
    }

    public static let neutral = AdaptiveExperienceTheme(from: .base(for: .balanced))
}

/// A partner app implements this to receive context updates (in a real
/// deployment, via App Group publication from the host app).
public protocol AdaptiveExperienceProviding: Sendable {
    func currentContext() async -> AdaptiveExperienceContext?
}

/// Static provider used by demos and tests.
public struct StaticAdaptiveExperienceProvider: AdaptiveExperienceProviding {
    private let context: AdaptiveExperienceContext

    public init(context: AdaptiveExperienceContext) {
        self.context = context
    }

    public func currentContext() async -> AdaptiveExperienceContext? {
        context
    }
}

#if canImport(SwiftUI)
import SwiftUI

private struct AdaptiveExperienceThemeKey: EnvironmentKey {
    static let defaultValue: AdaptiveExperienceTheme = .neutral
}

public extension EnvironmentValues {
    var adaptiveExperienceTheme: AdaptiveExperienceTheme {
        get { self[AdaptiveExperienceThemeKey.self] }
        set { self[AdaptiveExperienceThemeKey.self] = newValue }
    }
}

/// Applies partner-side adjustments a participating view adopts.
public struct AdaptiveExperienceModifier: ViewModifier {
    let theme: AdaptiveExperienceTheme

    public init(theme: AdaptiveExperienceTheme) {
        self.theme = theme
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.adaptiveExperienceTheme, theme)
            .lineSpacing(4 * (theme.lineSpacingMultiplier - 1.0) * 10)
    }
}

public extension View {
    /// Partner entry point: `MyFeedView().adaptiveExperience(theme)`.
    func adaptiveExperience(_ theme: AdaptiveExperienceTheme) -> some View {
        modifier(AdaptiveExperienceModifier(theme: theme))
    }
}
#endif
