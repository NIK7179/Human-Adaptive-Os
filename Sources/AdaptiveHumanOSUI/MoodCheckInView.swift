#if canImport(SwiftUI)
import SwiftUI
import AdaptiveHumanOS

/// Respectful manual mood check-in (Section C.6/C.11 D). Everything is
/// optional, nothing is inferred, and the data never leaves the device.
public struct MoodCheckInView: View {
    let onComplete: () -> Void

    @State private var valence: Double = 0.5
    @State private var energy: Double = 0.5
    @State private var selectedTags: Set<String> = []
    @State private var note: String = ""
    @Environment(\.dismiss) private var dismiss

    private let tags = ["Stressed", "Focused", "Tired", "Joyful", "Overwhelmed", "Calm"]

    public init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("How are you feeling right now? Only what you choose to share is used — nothing is guessed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Mood") {
                    VStack(alignment: .leading) {
                        Slider(value: $valence, in: 0...1)
                            .accessibilityLabel("Mood, from difficult to great")
                        HStack {
                            Text("Difficult").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("Great").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Energy") {
                    VStack(alignment: .leading) {
                        Slider(value: $energy, in: 0...1)
                            .accessibilityLabel("Energy, from drained to energized")
                        HStack {
                            Text("Drained").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("Energized").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Tags (optional)") {
                    FlowTagPicker(tags: tags, selection: $selectedTags)
                }
                Section("Note (optional, stays on this device)") {
                    TextField("Anything you want to remember", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Button("Save check-in") {
                        onComplete()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Check in")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// Simple wrapping tag picker.
struct FlowTagPicker: View {
    let tags: [String]
    @Binding var selection: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], alignment: .leading, spacing: AdaptiveSpacing.s) {
            ForEach(tags, id: \.self) { tag in
                let isSelected = selection.contains(tag)
                Button {
                    if isSelected { selection.remove(tag) } else { selection.insert(tag) }
                } label: {
                    Text(tag)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, AdaptiveSpacing.s)
                        .padding(.vertical, AdaptiveSpacing.xs)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(isSelected ? .accentColor : .secondary)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
#endif
