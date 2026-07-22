# Xcode setup for the AdaptiveHumanOS iOS app

The repository is a Swift Package. The decision engine (`AdaptiveHumanOS`)
and UI layer (`AdaptiveHumanOSUI`) build and test with `swift test` /
`swift build` on macOS and Linux. To run the app on an iPhone or simulator,
create a thin app target around the package:

1. Open Xcode 16 or newer → **File → New → Project… → iOS → App**.
   - Product name: `AdaptiveHumanOS`
   - Interface: SwiftUI, Language: Swift
   - Save it anywhere OUTSIDE this repository folder (e.g. `~/XcodeShells/`).
2. Delete the template `ContentView.swift`. Replace the template
   `<Product>App.swift` with the contents of `App/AdaptiveHumanOSApp.swift`.
3. **File → Add Package Dependencies… → Add Local…** and select this
   repository folder. Add all three products (`AdaptiveHumanOS`,
   `AdaptiveHumanOSUI`, `AdaptiveExperienceKit`) to the app target.
4. Set the deployment target to iOS 17.0 or newer (the UI uses the
   Observation framework).
5. In **Signing & Capabilities**, select your team and set a unique bundle
   identifier, e.g. `com.<yourname>.adaptivehumanos`
   (placeholder to replace: `com.example.adaptivehumanos`).
6. Build and run. The app launches into the Today dashboard running the
   **Late-night prolonged session** simulation scenario — the same fixture
   the keystone regression test verifies.

## Optional capabilities (not required to run the demo)

These are deliberately NOT wired into the code yet — the app is fully
functional on simulation data without them:

- **App Group** (for future widgets): add the App Groups capability with
  identifier `group.com.<yourname>.adaptivehumanos` to the app and any
  widget extension. Placeholder used in docs:
  `group.com.example.adaptivehumanos`.
- **WeatherKit**: add the WeatherKit capability (requires a paid Apple
  Developer account); register the bundle ID in the developer portal.
- **HealthKit**: add the HealthKit capability plus
  `NSHealthShareUsageDescription` in Info.plist.
- **Widgets / Live Activities**: add a Widget Extension target; Live
  Activities additionally require `NSSupportsLiveActivities = YES`.

## Running the package tests in Xcode

Open the repository folder directly in Xcode (as a package) and press
Cmd-U, or run `swift test` from the repository root on macOS. The keystone
regression fixture is
`Tests/AdaptiveHumanOSTests/ConfidenceRegressionTests.swift`.
