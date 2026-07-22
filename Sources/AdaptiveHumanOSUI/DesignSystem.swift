#if canImport(SwiftUI)
import SwiftUI
import AdaptiveHumanOS

// MARK: - Design system (Section C.18)
//
// Semantic tokens only — no raw RGB scattered through views. Every color
// resolves from the current `AdaptiveTheme`'s semantic levels, and adapts
// to Dark Mode automatically via system colors where possible.

public enum AdaptiveSpacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 16
    public static let l: CGFloat = 24
    public static let xl: CGFloat = 32
}

public enum AdaptiveCorner {
    public static let card: CGFloat = 16
    public static let chip: CGFloat = 10
}

public struct AdaptiveColors {
    public let background: Color
    public let surface: Color
    public let surfaceSecondary: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let accent: Color
    public let positive: Color
    public let caution: Color

    /// Maps semantic theme tokens to concrete colors.
    public static func palette(for theme: AdaptiveTheme) -> AdaptiveColors {
        let accent: Color
        switch theme.mode {
        case .eyeComfort, .sleepPreparation: accent = .orange
        case .calm, .recovery, .lowStimulation: accent = .teal
        case .energize, .socialConnection: accent = .pink
        case .focus, .interviewPreparation: accent = .indigo
        case .outdoorVisibility, .commute: accent = .blue
        case .balanced, .manualCustom: accent = .accentColor
        }
        let background: Color
        let surface: Color
        switch theme.background {
        case .neutral, .cool:
            background = Color(white: 0.97)
            surface = .white
        case .soft:
            background = Color(hue: 0.55, saturation: 0.04, brightness: 0.97)
            surface = .white
        case .warmDim:
            background = Color(hue: 0.09, saturation: 0.10, brightness: 0.94)
            surface = Color(hue: 0.09, saturation: 0.05, brightness: 0.98)
        case .warmDark:
            background = Color(hue: 0.08, saturation: 0.25, brightness: 0.12)
            surface = Color(hue: 0.08, saturation: 0.20, brightness: 0.18)
        case .highContrastLight:
            background = .white
            surface = Color(white: 0.94)
        case .highContrastDark:
            background = .black
            surface = Color(white: 0.12)
        }
        let darkText = theme.background == .warmDark || theme.background == .highContrastDark
        return AdaptiveColors(
            background: background,
            surface: surface,
            surfaceSecondary: darkText ? Color(white: 0.22) : Color(white: 0.92),
            textPrimary: darkText ? Color(white: 0.95) : Color(white: 0.10),
            textSecondary: darkText ? Color(white: 0.70) : Color(white: 0.40),
            accent: accent,
            positive: .green,
            caution: .orange
        )
    }
}

public enum AdaptiveTypography {
    /// Scales a text style by the theme's font scale while preserving
    /// Dynamic Type (relative styles, never fixed sizes below system).
    public static func scaledFont(_ style: Font.TextStyle, theme: AdaptiveTheme, weight: Font.Weight? = nil) -> Font {
        let baseWeight: Font.Weight
        if let weight {
            baseWeight = weight
        } else {
            switch theme.fontWeightAdjustment {
            case ..<0: baseWeight = .light
            case 0: baseWeight = .regular
            default: baseWeight = .semibold
            }
        }
        return Font.system(style, design: .default).weight(baseWeight)
    }
}

public enum AdaptiveMotion {
    /// Animation respecting the theme's motion intensity; `nil` disables.
    public static func animation(for theme: AdaptiveTheme) -> Animation? {
        switch theme.motion {
        case .none: return nil
        case .minimal: return .easeInOut(duration: 0.35 * theme.animationDurationMultiplier)
        case .gentle: return .easeInOut(duration: 0.30 * theme.animationDurationMultiplier)
        case .standard: return .spring(duration: 0.30 * theme.animationDurationMultiplier)
        case .lively: return .spring(duration: 0.25 * theme.animationDurationMultiplier, bounce: 0.25)
        }
    }
}

// MARK: - Shared components

public struct AdaptiveCard<Content: View>: View {
    let theme: AdaptiveTheme
    @ViewBuilder let content: () -> Content

    public init(theme: AdaptiveTheme, @ViewBuilder content: @escaping () -> Content) {
        self.theme = theme
        self.content = content
    }

    public var body: some View {
        let colors = AdaptiveColors.palette(for: theme)
        content()
            .padding(AdaptiveSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AdaptiveCorner.card, style: .continuous)
                    .fill(colors.surface)
            )
    }
}

public struct ConfidenceMeter: View {
    let confidence: Double
    let theme: AdaptiveTheme

    public init(confidence: Double, theme: AdaptiveTheme) {
        self.confidence = confidence
        self.theme = theme
    }

    public var body: some View {
        let colors = AdaptiveColors.palette(for: theme)
        VStack(alignment: .leading, spacing: AdaptiveSpacing.xs) {
            HStack {
                Text("Decision confidence")
                    .font(.caption)
                    .foregroundStyle(colors.textSecondary)
                Spacer()
                Text(confidence, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(colors.textPrimary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(colors.surfaceSecondary)
                    Capsule()
                        .fill(colors.accent)
                        .frame(width: max(0, min(1, confidence)) * proxy.size.width)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Decision confidence \(Int(confidence * 100)) percent")
    }
}
#endif
