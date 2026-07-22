// Xcode-only — add to BOTH the iOS app target and the Widget Extension.
// Requires the App Group capability on both targets with the same
// identifier (placeholder: group.com.example.adaptivehumanos).
// The JSON codec (`SharedStateSerializer`) is core and Linux-tested; this
// file is only the App Group storage wrapper around it.
// NOT compiled or verified on Linux CI.

#if !os(Linux)
import Foundation
import AdaptiveHumanOS

/// Reads/writes the compact, non-sensitive `SharedAdaptiveState` through
/// the shared App Group container. Widgets and App Intents consume it;
/// the app writes it after every decision.
public struct AppGroupStateStore: Sendable {
    /// Replace with your own App Group identifier (XCODE_SETUP.md step 7).
    public static let defaultSuiteName = "group.com.example.adaptivehumanos"
    private static let stateKey = "adaptive.shared.state.v1"

    public let suiteName: String
    private let serializer = SharedStateSerializer()

    public init(suiteName: String = AppGroupStateStore.defaultSuiteName) {
        self.suiteName = suiteName
    }

    /// Nil when the App Group is misconfigured — callers must show the
    /// "widget data unavailable" state rather than crashing (Section C.22).
    private var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    public func save(_ state: SharedAdaptiveState) throws {
        guard let defaults else { throw SharedStateError.corruptPayload }
        defaults.set(try serializer.encode(state), forKey: Self.stateKey)
    }

    public func load() -> SharedAdaptiveState? {
        guard let data = defaults?.data(forKey: Self.stateKey) else { return nil }
        return try? serializer.decode(data)
    }

    public func clear() {
        defaults?.removeObject(forKey: Self.stateKey)
    }
}
#endif
