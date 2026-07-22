// Xcode-only — add to a WIDGET EXTENSION target (XCODE_SETUP.md step 6).
// Requires: widget extension + App Group shared with the app.
// NOT compiled or verified on Linux CI. Final validation requires widget
// preview/simulator execution.

#if canImport(WidgetKit) && canImport(SwiftUI)
import WidgetKit
import SwiftUI
import AdaptiveHumanOS

// MARK: Timeline

struct AdaptiveModeEntry: TimelineEntry {
    let date: Date
    let state: SharedAdaptiveState?
}

struct AdaptiveModeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AdaptiveModeEntry {
        AdaptiveModeEntry(date: Date(), state: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (AdaptiveModeEntry) -> Void) {
        completion(AdaptiveModeEntry(date: Date(), state: AppGroupStateStore().load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AdaptiveModeEntry>) -> Void) {
        let entry = AdaptiveModeEntry(date: Date(), state: AppGroupStateStore().load())
        // Modest refresh cadence; the app also reloads timelines after each
        // decision. Never poll aggressively (Section C.15).
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: Shared small views

private func modeSymbol(_ mode: AdaptiveMode) -> String {
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

struct UnavailableView: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "questionmark.circle")
            Text("Open the app once to connect this widget.")
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: Home Screen widget (small + medium)

struct AdaptiveModeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AdaptiveModeEntry

    var body: some View {
        if let state = entry.state {
            switch family {
            case .systemMedium:
                HStack(spacing: 12) {
                    icon(state)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.mode.displayName).font(.headline)
                        Text(state.headline).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        HStack(spacing: 6) {
                            Text("Confidence \(Int(state.confidence * 100))%").font(.caption2)
                            if state.isSimulated { simBadge }
                        }
                    }
                    Spacer()
                }
            default:
                VStack(alignment: .leading, spacing: 5) {
                    icon(state)
                    Text(state.mode.displayName).font(.headline).minimumScaleFactor(0.7)
                    Text(state.mode.shortExplanation).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    if state.isSimulated { simBadge }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            UnavailableView()
        }
    }

    private func icon(_ state: SharedAdaptiveState) -> some View {
        Image(systemName: modeSymbol(state.mode))
            .font(.title2)
            .foregroundStyle(.tint)
    }

    private var simBadge: some View {
        Text("SIM")
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(Capsule().fill(.secondary.opacity(0.2)))
    }
}

struct AdaptiveModeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AdaptiveModeWidget", provider: AdaptiveModeTimelineProvider()) { entry in
            AdaptiveModeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)   // iOS 17 API, matches deployment target
        }
        .configurationDisplayName("Current adaptive mode")
        .description("The mode Adaptive Human OS is in right now, and why.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: Lock Screen accessories

struct AdaptiveAccessoryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AdaptiveModeEntry

    var body: some View {
        if let state = entry.state {
            switch family {
            case .accessoryCircular:
                Gauge(value: state.confidence) {
                    Image(systemName: modeSymbol(state.mode))
                }
                .gaugeStyle(.accessoryCircularCapacity)
            case .accessoryInline:
                Label(state.mode.displayName, systemImage: modeSymbol(state.mode))
            default: // accessoryRectangular
                VStack(alignment: .leading, spacing: 1) {
                    Label(state.mode.displayName, systemImage: modeSymbol(state.mode))
                        .font(.headline)
                    Text(state.headline).font(.caption2).lineLimit(2)
                }
            }
        } else {
            Image(systemName: "questionmark.circle")
        }
    }
}

struct AdaptiveAccessoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AdaptiveAccessoryWidget", provider: AdaptiveModeTimelineProvider()) { entry in
            AdaptiveAccessoryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Adaptive mode (Lock Screen)")
        .description("Glanceable current mode and context.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: Bundle

@main
struct AdaptiveWidgetBundle: WidgetBundle {
    var body: some Widget {
        AdaptiveModeWidget()
        AdaptiveAccessoryWidget()
        #if canImport(ActivityKit)
        AdaptiveSessionLiveActivity()
        #endif
    }
}
#endif
