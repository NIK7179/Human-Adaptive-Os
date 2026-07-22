import Foundation

/// Everything the engine can react to. Full Section B.3 set.
public enum ContextSignalKind: String, Codable, CaseIterable, Sendable {
    case lateNight
    case earlyMorning
    case daytime
    case solarBrightness
    case outdoorLikelihood
    case lowAmbientVisibility
    case highAmbientVisibility
    case poorSleep
    case goodSleep
    case lowEnergy
    case highEnergy
    case negativeValence
    case positiveValence
    case reportedStress
    case reportedCalm
    case interactionFatigue
    case prolongedSession
    case rapidNavigation
    case upcomingInterview
    case activeFocusGoal
    case physicalActivity
    case inactivity
    case rainyWeather
    case pleasantWeather
    case highUV
    case thermalPressure
    case lowPowerMode
    case reducedMotionPreference
    case increasedContrastPreference
    case largeTextPreference
    case manualModeRequest
}

/// Where a signal came from. Reliability defaults per source live in
/// `AdaptiveScoringConfiguration`, not scattered through the code.
public enum ContextSignalSource: String, Codable, CaseIterable, Sendable {
    case userInput
    case healthKit
    case weatherKit
    case coreLocation
    case coreMotion
    case processInfo
    case systemAccessibility
    case interactionHistory
    case solarModel
    case simulation
}

/// A normalized observation about the user's context.
///
/// Rules (Section B.3):
/// - `normalizedValue` and `reliability` are always in `0.0...1.0`.
/// - Approximated signals carry lower reliability than direct measurements.
/// - Expired signals contribute nothing.
/// - A missing signal stays missing — it is never encoded as a zero value.
///   A zero `normalizedValue` means "measured and absent".
/// - Every signal carries a user-readable explanation.
public struct ContextSignal: Identifiable, Codable, Sendable {
    public let id: UUID
    public let kind: ContextSignalKind
    public let normalizedValue: Double
    public let reliability: Double
    public let source: ContextSignalSource
    public let timestamp: Date
    public let expiresAt: Date?
    public let isApproximation: Bool
    public let explanation: String

    public init(
        id: UUID,
        kind: ContextSignalKind,
        normalizedValue: Double,
        reliability: Double,
        source: ContextSignalSource,
        timestamp: Date,
        expiresAt: Date?,
        isApproximation: Bool,
        explanation: String
    ) {
        self.id = id
        self.kind = kind
        self.normalizedValue = min(max(normalizedValue, 0.0), 1.0)
        self.reliability = min(max(reliability, 0.0), 1.0)
        self.source = source
        self.timestamp = timestamp
        self.expiresAt = expiresAt
        self.isApproximation = isApproximation
        self.explanation = explanation
    }

    /// A signal contributes only while unexpired at the single evaluation
    /// timestamp captured at pipeline start (B.23A timestamp policy).
    public func isValid(at evaluationTime: Date) -> Bool {
        guard let expiresAt else { return true }
        return evaluationTime < expiresAt
    }
}
