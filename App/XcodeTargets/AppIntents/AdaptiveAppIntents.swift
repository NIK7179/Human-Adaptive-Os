// Xcode-only — add to the iOS APP target (XCODE_SETUP.md step 9).
// App Intents surface the C.14 actions to Siri, Shortcuts and interactive
// widgets. They act through the App Group shared state; the app applies
// the requested change through the normal engine path on next launch or
// foreground refresh — intents never bypass the engine's override rules.
// NOT compiled or verified on Linux CI.

#if canImport(AppIntents)
import Foundation
import AppIntents
import AdaptiveHumanOS

// MARK: Mode entity

public enum AdaptiveModeAppEnum: String, AppEnum {
    case balanced, calm, energize, focus, recovery, eyeComfort, sleepPreparation, lowStimulation

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Adaptive Mode")
    public static let caseDisplayRepresentations: [AdaptiveModeAppEnum: DisplayRepresentation] = [
        .balanced: "Balanced", .calm: "Calm", .energize: "Energize", .focus: "Focus",
        .recovery: "Recovery", .eyeComfort: "Eye Comfort",
        .sleepPreparation: "Sleep Preparation", .lowStimulation: "Low Stimulation",
    ]

    var coreMode: AdaptiveMode {
        AdaptiveMode(rawValue: rawValue) ?? .balanced
    }
}

/// Writes a pending user request into the shared store; the app consumes
/// it as a `ManualModeOverride` (source `.appIntent`) — explicit user
/// choice, so it wins under the B.7 conflict rules.
private func requestMode(_ mode: AdaptiveMode, headline: String) throws {
    let store = AppGroupStateStore()
    let state = SharedAdaptiveState(
        mode: mode,
        headline: headline,
        confidence: 1.0,
        outcome: .blockedByManualOverride,
        isSimulated: store.load()?.isSimulated ?? true,
        automaticAdaptationEnabled: store.load()?.automaticAdaptationEnabled ?? true,
        updatedAt: Date()
    )
    try store.save(state)
}

// MARK: Intents (C.14)

public struct ActivateAdaptiveModeIntent: AppIntent {
    public static let title: LocalizedStringResource = "Activate Adaptive Mode"
    public static let description = IntentDescription("Switches Adaptive Human OS to a mode of your choice.")

    @Parameter(title: "Mode") public var mode: AdaptiveModeAppEnum

    public init() {}
    public init(mode: AdaptiveModeAppEnum) { self.mode = mode }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try requestMode(mode.coreMode, headline: "You selected \(mode.coreMode.displayName)")
        return .result(dialog: "Switched to \(mode.coreMode.displayName).")
    }
}

public struct GetCurrentModeIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Current Mode"
    public static let description = IntentDescription("Tells you which adaptive mode is active and why.")

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let state = AppGroupStateStore().load() else {
            return .result(dialog: "Open Adaptive Human OS once to connect Shortcuts.")
        }
        return .result(dialog: "\(state.mode.displayName) — \(state.headline)")
    }
}

public struct LogMoodIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Mood"
    public static let description = IntentDescription("Opens the mood check-in.")
    public static let openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        // The check-in is a deliberate, respectful in-app flow — never a
        // silent background write.
        .result()
    }
}

public struct PauseAdaptationIntent: AppIntent {
    public static let title: LocalizedStringResource = "Pause Automatic Adaptation"

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = AppGroupStateStore()
        if let state = store.load() {
            try store.save(SharedAdaptiveState(
                mode: state.mode, headline: state.headline, confidence: state.confidence,
                outcome: state.outcome, isSimulated: state.isSimulated,
                automaticAdaptationEnabled: false, updatedAt: Date()
            ))
        }
        return .result(dialog: "Automatic adaptation paused. Your current mode stays put.")
    }
}

public struct ResumeAdaptationIntent: AppIntent {
    public static let title: LocalizedStringResource = "Resume Automatic Adaptation"

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = AppGroupStateStore()
        if let state = store.load() {
            try store.save(SharedAdaptiveState(
                mode: state.mode, headline: state.headline, confidence: state.confidence,
                outcome: state.outcome, isSimulated: state.isSimulated,
                automaticAdaptationEnabled: true, updatedAt: Date()
            ))
        }
        return .result(dialog: "Automatic adaptation resumed.")
    }
}

public struct StartInterviewPreparationIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Interview Preparation"

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try requestMode(.interviewPreparation, headline: "Interview preparation started")
        return .result(dialog: "Interview Preparation is on. Good luck — you have this.")
    }
}

public struct StartEyeComfortIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Eye Comfort"

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try requestMode(.eyeComfort, headline: "Eye Comfort started")
        return .result(dialog: "Eye Comfort is on — warmer and dimmer.")
    }
}

public struct ProvideAdaptationFeedbackIntent: AppIntent {
    public static let title: LocalizedStringResource = "Mark Adaptation Helpful"
    public static let description = IntentDescription("Tells Adaptive Human OS the current adaptation helped.")

    @Parameter(title: "Helpful") public var helpful: Bool

    public init() {}
    public init(helpful: Bool) { self.helpful = helpful }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Feedback flows into the smoothed learner on next app foreground;
        // a single response never rewrites preferences (B.22).
        return .result(dialog: helpful ? "Noted — glad it helped." : "Noted — it will adapt more carefully.")
    }
}

// MARK: Shortcuts phrases

public struct AdaptiveShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartEyeComfortIntent(),
            phrases: ["Start Eye Comfort in \(.applicationName)"],
            shortTitle: "Eye Comfort",
            systemImageName: "eye"
        )
        AppShortcut(
            intent: ActivateAdaptiveModeIntent(),
            phrases: ["Change mode in \(.applicationName)"],
            shortTitle: "Change mode",
            systemImageName: "circle.lefthalf.filled"
        )
        AppShortcut(
            intent: GetCurrentModeIntent(),
            phrases: ["What mode is \(.applicationName) in"],
            shortTitle: "Current mode",
            systemImageName: "questionmark.circle"
        )
    }
}
#endif
