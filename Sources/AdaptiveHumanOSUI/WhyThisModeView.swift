#if canImport(SwiftUI)
import SwiftUI
import AdaptiveHumanOS

/// Full explainability surface (Section B.18): what pushed toward the mode,
/// what pushed against it, what was ignored or unavailable, which data
/// sources were used, and how to undo.
public struct WhyThisModeView: View {
    let decision: AdaptationDecision

    public init(decision: AdaptationDecision) {
        self.decision = decision
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: AdaptiveSpacing.s) {
                        Text(decision.explanation.headline)
                            .font(.headline)
                        Text(decision.explanation.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ConfidenceMeter(
                            confidence: decision.confidence.overall,
                            theme: decision.theme
                        )
                    }
                    .padding(.vertical, AdaptiveSpacing.xs)
                }

                if !decision.explanation.topPositiveFactors.isEmpty {
                    Section("Pushed toward \(decision.selectedMode.displayName)") {
                        ForEach(decision.explanation.topPositiveFactors) { factor in
                            factorRow(factor, positive: true)
                        }
                    }
                }

                if !decision.explanation.topNegativeFactors.isEmpty {
                    Section("Pushed against it") {
                        ForEach(decision.explanation.topNegativeFactors) { factor in
                            factorRow(factor, positive: false)
                        }
                    }
                }

                Section("Confidence breakdown") {
                    breakdownRow("Winning score", decision.confidence.winningScore)
                    breakdownRow("Margin over runner-up", decision.confidence.normalizedScoreMargin)
                    breakdownRow("Evidence reliability", decision.confidence.averageReliability)
                    breakdownRow("Signal freshness", decision.confidence.freshnessFactor)
                    LabeledContent("Independent signals") {
                        Text("\(decision.confidence.independentSignalCount)")
                    }
                    LabeledContent("Conflicting signals") {
                        Text("\(decision.confidence.conflictingSignalCount)")
                    }
                }

                if !decision.explanation.unavailableSignals.isEmpty {
                    Section("Not available") {
                        ForEach(decision.explanation.unavailableSignals, id: \.name) { unavailable in
                            VStack(alignment: .leading) {
                                Text(unavailable.name).font(.subheadline)
                                Text(unavailable.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Privacy") {
                    Text(decision.explanation.privacySummary)
                        .font(.subheadline)
                    if !decision.explanation.dataSourcesUsed.isEmpty {
                        LabeledContent("Sources used") {
                            Text(decision.explanation.dataSourcesUsed.map(\.rawValue).joined(separator: ", "))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Undo") {
                    Text(decision.explanation.undoDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Why this mode?")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private func factorRow(_ factor: ExplanationFactor, positive: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AdaptiveSpacing.s) {
            Image(systemName: positive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(positive ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(factor.title).font(.subheadline.weight(.medium))
                    if factor.isApproximation {
                        Text("estimate")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                }
                Text(factor.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(String(format: "%+.2f", factor.contribution))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func breakdownRow(_ title: String, _ value: Double) -> some View {
        LabeledContent(title) {
            Text(value, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
        }
    }
}
#endif
