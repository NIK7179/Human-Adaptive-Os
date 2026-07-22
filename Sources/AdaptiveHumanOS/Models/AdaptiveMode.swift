import Foundation

/// The primary interface modes the system can select. Section C.4 superset;
/// the Section A keystone exercises the first eight plus
/// `lowStimulation`/`interviewPreparation`.
public enum AdaptiveMode: String, Codable, CaseIterable, Sendable {
    case balanced
    case calm
    case energize
    case focus
    case recovery
    case eyeComfort
    case sleepPreparation
    case outdoorVisibility
    case lowStimulation
    case socialConnection
    case interviewPreparation
    case commute
    case manualCustom

    public var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .calm: return "Calm"
        case .energize: return "Energize"
        case .focus: return "Focus"
        case .recovery: return "Recovery"
        case .eyeComfort: return "Eye Comfort"
        case .sleepPreparation: return "Sleep Preparation"
        case .outdoorVisibility: return "Outdoor Visibility"
        case .lowStimulation: return "Low Stimulation"
        case .socialConnection: return "Social Connection"
        case .interviewPreparation: return "Interview Preparation"
        case .commute: return "Commute"
        case .manualCustom: return "Custom"
        }
    }

    public var shortExplanation: String {
        switch self {
        case .balanced: return "A neutral, comfortable default."
        case .calm: return "Softer contrast and slower motion for winding down."
        case .energize: return "Brighter, livelier presentation for active moments."
        case .focus: return "Reduced distraction for concentrated work."
        case .recovery: return "Gentle presentation after poor rest."
        case .eyeComfort: return "Warmer, dimmer presentation for tired eyes."
        case .sleepPreparation: return "Minimal stimulation ahead of sleep."
        case .outdoorVisibility: return "Maximum contrast for bright surroundings."
        case .lowStimulation: return "The quietest possible presentation."
        case .socialConnection: return "A warmer presentation for staying in touch."
        case .interviewPreparation: return "Structured, distraction-free preparation."
        case .commute: return "Glanceable layout for on-the-go moments."
        case .manualCustom: return "Your own configured presentation."
        }
    }
}
