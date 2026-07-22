// App shell for the Xcode iOS app target. NOT part of the SwiftPM build —
// create an iOS App target in Xcode, add the local package products
// `AdaptiveHumanOS`, `AdaptiveHumanOSUI` and `AdaptiveExperienceKit`, and
// include this file. See App/XCODE_SETUP.md for numbered steps.

#if canImport(SwiftUI)
import SwiftUI
import AdaptiveHumanOSUI

@main
struct AdaptiveHumanOSApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
#endif
