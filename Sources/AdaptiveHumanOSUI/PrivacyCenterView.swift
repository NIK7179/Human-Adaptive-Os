#if canImport(SwiftUI)
import SwiftUI
import AdaptiveHumanOS

/// Privacy Center (Section C.11 G): every data source, its state, what is
/// stored, and full deletion controls. Honest about what this build can and
/// cannot access.
public struct PrivacyCenterView: View {
    @Bindable var model: DashboardViewModel
    @State private var confirmingDelete = false

    public init(model: DashboardViewModel) {
        self.model = model
    }

    public var body: some View {
        List {
            Section {
                Label {
                    Text("Everything is evaluated on this device. Nothing is uploaded, sold, or used for advertising.")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.green)
                }
            }

            Section("Data sources") {
                sourceRow("Simulation data", state: "Active", detail: "This build runs on labeled simulation scenarios.")
                sourceRow("Mood check-ins", state: "Manual only", detail: "Used only when you check in yourself.")
                sourceRow("In-app session activity", state: model.preferences.interactionEstimateEnabled ? "On" : "Off (default)", detail: "Never reads other apps, keyboards, microphone or camera.")
                sourceRow("HealthKit (sleep, State of Mind)", state: "Not connected", detail: "Requires entitlement + your explicit permission on a device build.")
                sourceRow("WeatherKit", state: "Not connected", detail: "Requires the WeatherKit capability on a device build.")
                sourceRow("Location (solar phase)", state: "Not connected", detail: "When denied, a clearly-labeled clock-based approximation is used.")
            }

            Section("Stored on this device") {
                LabeledContent("Adaptation timeline entries", value: "\(model.history.entries.count)")
                LabeledContent("Learned mode preferences", value: "\(model.preferences.personalization.count)")
                Text("No raw health data, no location history, no journal text unless you deliberately save it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Your controls") {
                Button("Reset learned preferences") {
                    model.resetLearnedPreferences()
                }
                Button("Delete all adaptation history", role: .destructive) {
                    confirmingDelete = true
                }
            }

            Section("What this app never does") {
                ForEach(neverList, id: \.self) { item in
                    Label(item, systemImage: "xmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Privacy Center")
        .confirmationDialog(
            "Delete all adaptation history?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) {
                model.deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var neverList: [String] {
        [
            "Diagnose mood, mental health or medical conditions",
            "Read messages, keyboard input or other apps",
            "Use microphone or camera for emotion recognition",
            "Sell data or build advertising profiles",
            "Claim to restyle Instagram, WhatsApp or other apps",
        ]
    }

    private func sourceRow(_ name: String, state: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.subheadline)
                Spacer()
                Text(state)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
