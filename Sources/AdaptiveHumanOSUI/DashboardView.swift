#if canImport(SwiftUI)
import SwiftUI
import AdaptiveHumanOS

/// The Today dashboard (Section C.11 B): current mode, context summary,
/// "Why this mode?", suggestion banner, quick check-in, comfort score,
/// fatigue indicator, manual mode selector, feedback and undo.
public struct DashboardView: View {
    @Bindable var model: DashboardViewModel
    @State private var showWhy = false
    @State private var showMoodCheckIn = false

    public init(model: DashboardViewModel) {
        self.model = model
    }

    public var body: some View {
        let theme = model.activeTheme
        let colors = AdaptiveColors.palette(for: theme)
        ScrollView {
            VStack(spacing: AdaptiveSpacing.m) {
                simulationBadge(colors: colors)
                currentModeCard(theme: theme, colors: colors)
                if let suggestion = model.pendingSuggestion {
                    suggestionBanner(suggestion, theme: theme, colors: colors)
                }
                contextSummary(theme: theme, colors: colors)
                comfortCard(theme: theme, colors: colors)
                modeSelector(theme: theme, colors: colors)
                feedbackRow(theme: theme, colors: colors)
            }
            .padding(AdaptiveSpacing.m)
        }
        .background(colors.background.ignoresSafeArea())
        .animation(AdaptiveMotion.animation(for: theme), value: model.activeMode)
        .navigationTitle("Today")
        .sheet(isPresented: $showWhy) {
            if let decision = model.decision {
                WhyThisModeView(decision: decision)
            }
        }
        .sheet(isPresented: $showMoodCheckIn) {
            MoodCheckInView { showMoodCheckIn = false; model.recordMoodCheckIn() }
        }
    }

    @ViewBuilder
    private func simulationBadge(colors: AdaptiveColors) -> some View {
        HStack(spacing: AdaptiveSpacing.s) {
            Image(systemName: "wand.and.stars")
            Text("Simulation: \(model.scenario.displayName)")
                .font(.footnote)
            Spacer()
            Menu {
                ForEach(SimulationScenario.allCases) { scenario in
                    Button(scenario.displayName) { model.scenario = scenario }
                }
            } label: {
                Text("Change")
                    .font(.footnote.weight(.semibold))
            }
        }
        .foregroundStyle(colors.textSecondary)
        .padding(.horizontal, AdaptiveSpacing.s)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func currentModeCard(theme: AdaptiveTheme, colors: AdaptiveColors) -> some View {
        AdaptiveCard(theme: theme) {
            VStack(alignment: .leading, spacing: AdaptiveSpacing.s) {
                HStack {
                    Label(model.activeMode.displayName, systemImage: icon(for: model.activeMode))
                        .font(AdaptiveTypography.scaledFont(.title2, theme: theme, weight: .semibold))
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    if model.isEvaluating {
                        ProgressView()
                    }
                }
                Text(model.activeMode.shortExplanation)
                    .font(.subheadline)
                    .foregroundStyle(colors.textSecondary)
                if let decision = model.decision {
                    ConfidenceMeter(confidence: decision.confidence.overall, theme: theme)
                    HStack {
                        Button {
                            showWhy = true
                        } label: {
                            Label("Why this mode?", systemImage: "questionmark.circle")
                                .font(.callout.weight(.medium))
                        }
                        .buttonStyle(.borderless)
                        .tint(colors.accent)
                        Spacer()
                        if decision.outcome == .applied {
                            Button("Undo", systemImage: "arrow.uturn.backward") {
                                model.undoLastAdaptation()
                            }
                            .buttonStyle(.borderless)
                            .tint(colors.accent)
                        }
                    }
                }
                if model.history.activeOverride != nil {
                    HStack(spacing: AdaptiveSpacing.xs) {
                        Image(systemName: "hand.raised.fill")
                        Text("Manual selection active — automatic changes paused.")
                        Spacer()
                        Button("End") { model.endManualOverride() }
                            .font(.footnote.weight(.semibold))
                    }
                    .font(.footnote)
                    .foregroundStyle(colors.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func suggestionBanner(
        _ suggestion: AdaptationDecision, theme: AdaptiveTheme, colors: AdaptiveColors
    ) -> some View {
        AdaptiveCard(theme: theme) {
            VStack(alignment: .leading, spacing: AdaptiveSpacing.s) {
                Label(suggestion.explanation.headline, systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(colors.textPrimary)
                Text(suggestion.explanation.summary)
                    .font(.subheadline)
                    .foregroundStyle(colors.textSecondary)
                HStack(spacing: AdaptiveSpacing.m) {
                    Button("Switch to \(suggestion.selectedMode.displayName)") {
                        model.acceptSuggestion()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(colors.accent)
                    Button("Not now") { model.dismissSuggestion() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggestion: \(suggestion.explanation.headline)")
    }

    @ViewBuilder
    private func contextSummary(theme: AdaptiveTheme, colors: AdaptiveColors) -> some View {
        let snapshot = model.snapshot
        AdaptiveCard(theme: theme) {
            VStack(alignment: .leading, spacing: AdaptiveSpacing.s) {
                Text("Context")
                    .font(.headline)
                    .foregroundStyle(colors.textPrimary)
                Grid(alignment: .leading, horizontalSpacing: AdaptiveSpacing.m, verticalSpacing: AdaptiveSpacing.s) {
                    GridRow {
                        contextItem("clock", String(format: "%02d:00", snapshot.localHour), colors: colors)
                        contextItem(weatherIcon(snapshot), weatherText(snapshot), colors: colors)
                    }
                    GridRow {
                        contextItem("bed.double", sleepText(snapshot), colors: colors)
                        contextItem("gauge", "Fatigue: \(fatigueText)", colors: colors)
                    }
                }
                Button {
                    showMoodCheckIn = true
                } label: {
                    Label("Quick mood check-in", systemImage: "face.smiling")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(colors.accent)
            }
        }
    }

    private func contextItem(_ symbol: String, _ text: String, colors: AdaptiveColors) -> some View {
        HStack(spacing: AdaptiveSpacing.xs) {
            Image(systemName: symbol)
                .foregroundStyle(colors.accent)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(colors.textPrimary)
        }
    }

    @ViewBuilder
    private func comfortCard(theme: AdaptiveTheme, colors: AdaptiveColors) -> some View {
        AdaptiveCard(theme: theme) {
            VStack(alignment: .leading, spacing: AdaptiveSpacing.s) {
                Text("Estimated interface comfort")
                    .font(.headline)
                    .foregroundStyle(colors.textPrimary)
                if let score = model.comfort?.score {
                    HStack(alignment: .firstTextBaseline, spacing: AdaptiveSpacing.xs) {
                        Text("\(score)")
                            .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                            .foregroundStyle(colors.textPrimary)
                        Text("/ 100")
                            .font(.subheadline)
                            .foregroundStyle(colors.textSecondary)
                    }
                } else {
                    Text("Not enough information to estimate interface comfort yet.")
                        .font(.subheadline)
                        .foregroundStyle(colors.textSecondary)
                }
                Text("An estimate about this interface only — never a health measurement.")
                    .font(.caption2)
                    .foregroundStyle(colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func modeSelector(theme: AdaptiveTheme, colors: AdaptiveColors) -> some View {
        AdaptiveCard(theme: theme) {
            VStack(alignment: .leading, spacing: AdaptiveSpacing.s) {
                Text("Choose a mode yourself")
                    .font(.headline)
                    .foregroundStyle(colors.textPrimary)
                Text("Your choice always wins. Automatic changes pause until it ends.")
                    .font(.caption)
                    .foregroundStyle(colors.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AdaptiveSpacing.s) {
                        ForEach(manualModes, id: \.self) { mode in
                            Button {
                                model.beginManualOverride(mode: mode, duration: 30 * 60)
                            } label: {
                                Label(mode.displayName, systemImage: icon(for: mode))
                                    .font(.footnote.weight(.medium))
                                    .padding(.horizontal, AdaptiveSpacing.s)
                                    .padding(.vertical, AdaptiveSpacing.xs)
                            }
                            .buttonStyle(.bordered)
                            .tint(mode == model.activeMode ? colors.accent : colors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func feedbackRow(theme: AdaptiveTheme, colors: AdaptiveColors) -> some View {
        AdaptiveCard(theme: theme) {
            VStack(alignment: .leading, spacing: AdaptiveSpacing.s) {
                Text("How is this working?")
                    .font(.headline)
                    .foregroundStyle(colors.textPrimary)
                HStack(spacing: AdaptiveSpacing.m) {
                    Button("This helped", systemImage: "hand.thumbsup") {
                        model.sendFeedback(.helpful)
                    }
                    Button("Not helpful", systemImage: "hand.thumbsdown") {
                        model.sendFeedback(.unhelpful)
                    }
                }
                .buttonStyle(.bordered)
                .tint(colors.accent)
                .font(.footnote)
            }
        }
    }

    private var manualModes: [AdaptiveMode] {
        [.balanced, .calm, .focus, .eyeComfort, .energize, .recovery, .lowStimulation]
    }

    private var fatigueText: String {
        switch model.fatigueLevel {
        case .unavailable: return "—"
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }

    private func sleepText(_ snapshot: ContextSnapshot) -> String {
        guard let hours = snapshot.sleepDurationHours else { return "No sleep data" }
        return String(format: "%.1f h sleep", hours)
    }

    private func weatherText(_ snapshot: ContextSnapshot) -> String {
        guard let weather = snapshot.weather else { return "No weather data" }
        switch weather.condition {
        case .clear: return "Clear"
        case .partlyCloudy: return "Partly cloudy"
        case .overcast: return "Overcast"
        case .rain: return "Rain"
        case .snow: return "Snow"
        case .storm: return "Storm"
        case .fog: return "Fog"
        case .unknown: return "Weather unknown"
        }
    }

    private func weatherIcon(_ snapshot: ContextSnapshot) -> String {
        guard let weather = snapshot.weather else { return "questionmark.circle" }
        switch weather.condition {
        case .clear: return "sun.max"
        case .partlyCloudy: return "cloud.sun"
        case .overcast: return "cloud"
        case .rain: return "cloud.rain"
        case .snow: return "cloud.snow"
        case .storm: return "cloud.bolt.rain"
        case .fog: return "cloud.fog"
        case .unknown: return "questionmark.circle"
        }
    }

    private func icon(for mode: AdaptiveMode) -> String {
        switch mode {
        case .balanced: return "circle.lefthalf.filled"
        case .calm: return "leaf"
        case .energize: return "bolt"
        case .focus: return "scope"
        case .recovery: return "heart"
        case .eyeComfort: return "eye"
        case .sleepPreparation: return "moon.zzz"
        case .outdoorVisibility: return "sun.max"
        case .lowStimulation: return "minus.circle"
        case .socialConnection: return "person.2"
        case .interviewPreparation: return "briefcase"
        case .commute: return "tram"
        case .manualCustom: return "slider.horizontal.3"
        }
    }
}
#endif
