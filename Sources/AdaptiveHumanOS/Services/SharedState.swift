import Foundation

// MARK: - App Group shared state (codec is core; storage is Xcode-only)
//
// Widgets and App Intents read this compact, non-sensitive summary. It
// deliberately contains presentation state only — no mood values, no health
// data, no location. The JSON codec round-trips deterministically and is
// Linux-tested; the App Group `UserDefaults(suiteName:)` storage adapter
// lives in App/XcodeTargets/Shared and is not verified here.

public struct SharedAdaptiveState: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public let version: Int
    public let mode: AdaptiveMode
    public let headline: String
    public let confidence: Double
    public let outcome: AdaptationOutcome
    public let isSimulated: Bool
    public let automaticAdaptationEnabled: Bool
    public let updatedAt: Date

    public init(
        version: Int = SharedAdaptiveState.currentVersion,
        mode: AdaptiveMode,
        headline: String,
        confidence: Double,
        outcome: AdaptationOutcome,
        isSimulated: Bool,
        automaticAdaptationEnabled: Bool,
        updatedAt: Date
    ) {
        self.version = version
        self.mode = mode
        self.headline = headline
        self.confidence = confidence
        self.outcome = outcome
        self.isSimulated = isSimulated
        self.automaticAdaptationEnabled = automaticAdaptationEnabled
        self.updatedAt = updatedAt
    }

    public init(decision: AdaptationDecision, automaticAdaptationEnabled: Bool, isSimulated: Bool) {
        self.init(
            mode: decision.selectedMode,
            headline: decision.explanation.headline,
            confidence: decision.confidence.overall,
            outcome: decision.outcome,
            isSimulated: isSimulated,
            automaticAdaptationEnabled: automaticAdaptationEnabled,
            updatedAt: decision.evaluatedAt
        )
    }
}

public enum SharedStateError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case corruptPayload
}

/// Deterministic JSON codec: sorted keys, epoch-seconds dates — identical
/// input state always yields identical bytes.
public struct SharedStateSerializer: Sendable {
    public init() {}

    public func encode(_ state: SharedAdaptiveState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(state)
    }

    public func decode(_ data: Data) throws -> SharedAdaptiveState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let state = try? decoder.decode(SharedAdaptiveState.self, from: data) else {
            throw SharedStateError.corruptPayload
        }
        guard state.version <= SharedAdaptiveState.currentVersion else {
            throw SharedStateError.unsupportedVersion(state.version)
        }
        return state
    }
}
