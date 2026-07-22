import Foundation

/// Every way an evaluation can end (Section B.9 superset of the keystone's
/// three cases). The engine never adapts merely because context exists.
public enum AdaptationOutcome: String, Codable, Sendable {
    case applied
    case suggested
    case unchangedLowConfidence
    case unchangedCooldown
    case unchangedInsufficientDifference
    case blockedByManualOverride
    case blockedByUserPreference
    case blockedByCapability

    /// True when the interface actually changed.
    public var changedInterface: Bool { self == .applied }
}
