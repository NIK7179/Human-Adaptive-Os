#if canImport(SwiftUI)
import SwiftUI
import AdaptiveHumanOS

/// Settings (Section C.11 H): automatic adaptation, sensitivity, simulation
/// scenario, personalization controls, learned-preference reset.
public struct SettingsView: View {
    @Bindable var model: DashboardViewModel

    public init(model: DashboardViewModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section("Adaptation") {
                Toggle("Automatic adaptation", isOn: Binding(
                    get: { model.preferences.automaticAdaptationEnabled },
                    set: { model.preferences.automaticAdaptationEnabled = $0; model.evaluate() }
                ))
                VStack(alignment: .leading) {
                    Text("Sensitivity")
                    Slider(value: Binding(
                        get: { model.preferences.adaptationSensitivity },
                        set: { model.preferences.adaptationSensitivity = $0 }
                    ), in: 0...1)
                    Text("Lower sensitivity means fewer, more certain changes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Prefer reduced stimulation", isOn: Binding(
                    get: { model.preferences.reducedStimulationPreferred },
                    set: { model.preferences.reducedStimulationPreferred = $0; model.evaluate() }
                ))
            }

            Section("Personalization") {
                Toggle("Learn from my feedback", isOn: Binding(
                    get: { model.preferences.personalizationEnabled },
                    set: { model.preferences.personalizationEnabled = $0; model.evaluate() }
                ))
                Toggle(isOn: Binding(
                    get: { model.preferences.interactionEstimateEnabled },
                    set: { model.preferences.interactionEstimateEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("In-app fatigue estimate")
                        Text("Off by default. Uses only activity inside this app — never other apps, typing, microphone or camera.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Reset learned preferences", role: .destructive) {
                    model.resetLearnedPreferences()
                }
            }

            Section("Developer · Simulation") {
                Picker("Scenario", selection: Binding(
                    get: { model.scenario },
                    set: { model.scenario = $0 }
                )) {
                    ForEach(SimulationScenario.allCases) { scenario in
                        Text(scenario.displayName).tag(scenario)
                    }
                }
                LabeledContent("Engine configuration", value: "Demo (fast reactions)")
                Text("All data on this build is simulated and labeled as such. Live WeatherKit/HealthKit integration requires device capabilities configured in Xcode — see the README.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Unavailable in this build") {
                unavailableRow("Widgets & Lock Screen widgets", "Requires a widget extension target with an App Group.")
                unavailableRow("Live Activities", "Requires ActivityKit entitlement and a widget extension.")
                unavailableRow("WeatherKit", "Requires the WeatherKit capability and an Apple Developer account.")
                unavailableRow("HealthKit sleep & State of Mind", "Requires HealthKit entitlement and user permission on device.")
            }
        }
        .navigationTitle("Settings")
    }

    private func unavailableRow(_ title: String, _ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: "lock")
                .font(.subheadline)
            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
