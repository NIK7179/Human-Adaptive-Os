#if canImport(SwiftUI)
import SwiftUI
import AdaptiveHumanOS
import AdaptiveExperienceKit

/// Root navigation. The app shell (`App/AdaptiveHumanOSApp.swift`, built in
/// Xcode) instantiates this view.
public struct AppRootView: View {
    @State private var model = DashboardViewModel()

    public init() {}

    public var body: some View {
        TabView {
            NavigationStack {
                DashboardView(model: model)
            }
            .tabItem { Label("Today", systemImage: "sun.and.horizon") }

            NavigationStack {
                HistoryView(model: model)
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack {
                PartnerDemoView(theme: partnerTheme)
            }
            .tabItem { Label("Partner demo", systemImage: "square.grid.2x2") }

            NavigationStack {
                PrivacyCenterView(model: model)
            }
            .tabItem { Label("Privacy", systemImage: "lock.shield") }

            NavigationStack {
                SettingsView(model: model)
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }

    /// The current adaptive theme translated into the partner SDK's
    /// voluntary-integration contract.
    private var partnerTheme: AdaptiveExperienceTheme {
        AdaptiveExperienceTheme(from: model.activeTheme)
    }
}
#endif
