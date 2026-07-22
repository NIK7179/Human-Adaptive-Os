#if canImport(SwiftUI)
import SwiftUI
import AdaptiveHumanOS

/// A mock "partner app" feed demonstrating voluntary SDK adoption
/// (Section C.11 C / C.17). This is a simulated mini-app inside our own
/// process — explicitly NOT an integration with any real third-party app.
public struct PartnerDemoView: View {
    let theme: AdaptiveExperienceTheme
    @State private var adoptTheme = true

    public init(theme: AdaptiveExperienceTheme) {
        self.theme = theme
    }

    public var body: some View {
        let active = adoptTheme ? theme : .neutral
        List {
            Section {
                Toggle("Adopt the Adaptive Human OS theme", isOn: $adoptTheme)
                Text("A simulated partner feed. Real third-party apps are never modified — a partner would link AdaptiveExperienceKit and opt in, exactly like this toggle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Sample partner feed") {
                ForEach(samplePosts, id: \.title) { post in
                    PartnerPostCard(post: post)
                        .adaptiveExperience(active)
                }
            }
            Section("What the partner receives") {
                LabeledContent("Contrast", value: active.contrast.rawValue)
                LabeledContent("Motion", value: active.motion.rawValue)
                LabeledContent("Complexity", value: active.complexity.rawValue)
                LabeledContent("Media intensity", value: String(format: "%.0f%%", active.mediaIntensity * 100))
                LabeledContent("Content density", value: String(format: "%.0f%%", active.contentDensity * 100))
                Text("No mood, health, or location data crosses the boundary — presentation intent only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Partner demo")
    }

    private var samplePosts: [PartnerPost] {
        [
            PartnerPost(title: "Weekend hike photos", body: "Twelve new photos from the ridge trail.", isMediaHeavy: true),
            PartnerPost(title: "Reading list", body: "Three long-form articles saved for later.", isMediaHeavy: false),
            PartnerPost(title: "Friends nearby", body: "Two friends checked in close to you.", isMediaHeavy: false),
        ]
    }
}

struct PartnerPost {
    let title: String
    let body: String
    let isMediaHeavy: Bool
}

struct PartnerPostCard: View {
    let post: PartnerPost
    @Environment(\.adaptiveExperienceTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(post.title)
                .font(.headline)
            if theme.contentDensity > 0.5 || !post.isMediaHeavy {
                Text(post.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if post.isMediaHeavy {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.secondary.opacity(0.15))
                    .frame(height: theme.mediaIntensity > 0.6 ? 120 : 44)
                    .overlay(
                        Label(
                            theme.mediaIntensity > 0.6 ? "Full media preview" : "Media minimized for comfort",
                            systemImage: "photo"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}
#endif
