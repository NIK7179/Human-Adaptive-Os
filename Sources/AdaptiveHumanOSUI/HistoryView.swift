#if canImport(SwiftUI)
import SwiftUI
import AdaptiveHumanOS

/// Adaptation timeline (Section B.20): every decision, its outcome, the top
/// reasons, and undo for the latest applied change.
public struct HistoryView: View {
    @Bindable var model: DashboardViewModel

    public init(model: DashboardViewModel) {
        self.model = model
    }

    public var body: some View {
        List {
            if model.timelineEntries.isEmpty {
                ContentUnavailableView(
                    "No adaptations yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Decisions will appear here as the engine evaluates your context.")
                )
            }
            ForEach(model.timelineEntries) { entry in
                VStack(alignment: .leading, spacing: AdaptiveSpacing.xs) {
                    HStack {
                        Image(systemName: symbol(for: entry.outcome))
                            .foregroundStyle(color(for: entry.outcome))
                        Text(title(for: entry))
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(entry.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !entry.topReasons.isEmpty {
                        Text(entry.topReasons.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: AdaptiveSpacing.s) {
                        Text(entry.wasAutomatic ? "Automatic" : "Manual")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        Text("Confidence \(Int(entry.confidence * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let response = entry.userResponse {
                            Text(responseText(response))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Undo last change", systemImage: "arrow.uturn.backward") {
                    model.undoLastAdaptation()
                }
                .disabled(!model.timelineEntries.contains {
                    $0.outcome == .applied && $0.endReason == nil
                })
            }
        }
    }

    private func title(for entry: AdaptationTimelineEntry) -> String {
        switch entry.outcome {
        case .applied:
            return "\(entry.previousMode.displayName) → \(entry.selectedMode.displayName)"
        case .suggested:
            return "Suggested \(entry.selectedMode.displayName)"
        default:
            return "Stayed in \(entry.previousMode.displayName)"
        }
    }

    private func symbol(for outcome: AdaptationOutcome) -> String {
        switch outcome {
        case .applied: return "checkmark.circle.fill"
        case .suggested: return "sparkles"
        case .blockedByManualOverride: return "hand.raised.fill"
        default: return "pause.circle"
        }
    }

    private func color(for outcome: AdaptationOutcome) -> Color {
        switch outcome {
        case .applied: return .green
        case .suggested: return .indigo
        case .blockedByManualOverride: return .orange
        default: return .secondary
        }
    }

    private func responseText(_ response: AdaptationUserResponse) -> String {
        switch response {
        case .kept: return "You kept it"
        case .reverted: return "You undid it"
        case .helpful: return "Marked helpful"
        case .unhelpful: return "Marked unhelpful"
        case .adjusted: return "You adjusted it"
        case .ignored: return "Ignored"
        }
    }
}
#endif
