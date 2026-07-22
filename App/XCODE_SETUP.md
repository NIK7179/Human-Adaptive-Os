# Xcode setup — complete numbered guide

The repository is a Swift Package whose engine and service layer compile
and test on Linux/macOS (`swift test`). Everything below builds the real
iOS app, widgets, Live Activities and App Intents around that package on
your Mac. Statuses for every component are in
[`../VERIFICATION_MATRIX.md`](../VERIFICATION_MATRIX.md).

Placeholders used throughout — replace both, consistently:

- Bundle ID: `com.example.adaptivehumanos`
- App Group: `group.com.example.adaptivehumanos`

## 1. Create the iOS app target

1. Xcode 16+ → **File → New → Project… → iOS → App**.
2. Product name `AdaptiveHumanOS`, Interface **SwiftUI**, Language **Swift**.
   Save the project **outside** this repository folder.
3. Project settings → the app target → **General → Minimum Deployments →
   iOS 17.0**.
4. Delete the template `ContentView.swift`. Replace the template
   `AdaptiveHumanOSApp.swift` with `App/AdaptiveHumanOSApp.swift` from this
   repo.

## 2. Add the package

5. **File → Add Package Dependencies… → Add Local…** → select this
   repository folder.
6. Add products `AdaptiveHumanOS`, `AdaptiveHumanOSUI` and
   `AdaptiveExperienceKit` to the **app target**.

## 3. Signing and identity

7. App target → **Signing & Capabilities** → select your **Team**.
8. Set the bundle identifier (replacing `com.example.adaptivehumanos`).
9. Build and run once on a **simulator** — the app must already work here,
   entirely on simulation data. Everything after this step is optional.

## 4. Provider adapters (app target)

10. Drag `App/XcodeTargets/Providers/` into the project. In the add dialog,
    tick **only the app target** under "Add to targets".
11. `SystemAmbientContextProvider` and `UserNotificationCenterProvider`
    need no capabilities. Wire them (plus the simulation providers as
    fallback) into `ContextSnapshotAssembler` where the app builds its
    snapshot.

## 5. App Group (needed by widgets, Live Activities, App Intents)

12. App target → Signing & Capabilities → **+ Capability → App Groups** →
    add `group.com.example.adaptivehumanos` (your version of it).
13. Drag `App/XcodeTargets/Shared/AppGroupStateStore.swift` into the
    project → add to the **app target** (the widget extension joins in
    step 6). Update `AppGroupStateStore.defaultSuiteName` to your group ID.

## 6. Widget Extension (Home Screen + Lock Screen widgets)

14. **File → New → Target… → iOS → Widget Extension**. Name it
    `AdaptiveHumanWidgets`. Untick "Include configuration app intent".
    Do **not** activate the scheme's template files — delete the generated
    sample widget source.
15. Add the `AdaptiveHumanOS` package product to the widget target
    (target → General → Frameworks and Libraries).
16. Add these files to the **widget target**:
    - `App/XcodeTargets/Widgets/AdaptiveWidgets.swift`
    - `App/XcodeTargets/Shared/AppGroupStateStore.swift` (second target
      membership — select the file, tick the widget target in the File
      Inspector)
17. Widget target → Signing & Capabilities → **App Groups** → the same
    group ID as step 12.

## 7. Live Activities

18. App target → **Info** tab → add key `NSSupportsLiveActivities` = `YES`.
19. Add to the **widget target**:
    `App/XcodeTargets/LiveActivities/AdaptiveLiveActivities.swift`
    (the `AdaptiveSessionLiveActivity` widget is already referenced by the
    bundle in `AdaptiveWidgets.swift`).
20. The `AdaptiveSessionManager` class in that same file belongs to the
    **app target** — either give the file dual target membership or split
    the manager out; dual membership is simplest.
21. Note: banners work in the simulator; the Dynamic Island and full
    behavior need a **physical device**.

## 8. App Intents & Shortcuts

22. Add `App/XcodeTargets/AppIntents/AdaptiveAppIntents.swift` to the
    **app target**. Build — the intents and Siri/Shortcuts phrases
    register automatically on first run.

## 9. WeatherKit

23. App target → Signing & Capabilities → **+ Capability → WeatherKit**.
24. In the [developer portal](https://developer.apple.com/account), the
    app's identifier must list the WeatherKit service (requires a **paid
    Apple Developer account**; allow ~30 minutes to propagate).
25. Add `App/XcodeTargets/Providers/WeatherKitWeatherProvider.swift`
    (already included via step 10) and swap it in for the simulation
    weather provider. Location: add `NSLocationWhenInUseUsageDescription`
    (step 11 text below) and request when-in-use authorization in context.

## 10. HealthKit

26. App target → Signing & Capabilities → **+ Capability → HealthKit**.
27. Info.plist usage descriptions (step 11) and swap
    `HealthKitDataProvider` in for the simulation health provider.
    State of Mind requires **iOS 18+ on a physical device**; on iOS 17 the
    adapter reports it unavailable and the engine degrades gracefully.

## 11. Info.plist usage descriptions (add exactly these keys)

| Key | Suggested text |
|---|---|
| `NSHealthShareUsageDescription` | "Reads last night's sleep and, if you allow it, your logged State of Mind, to soften the interface when you're tired. Never written, never uploaded." |
| `NSLocationWhenInUseUsageDescription` | "Used only to compute local sunrise/sunset and fetch nearby weather. Your location is never stored or shared." |
| `NSSupportsLiveActivities` | `YES` (Boolean) |

## 12. Simulator vs physical device

| Works fully on simulator | Needs a physical device |
|---|---|
| App, dashboard, all simulation scenarios | HealthKit real data (incl. State of Mind, iOS 18+) |
| Widgets (Home Screen + Lock Screen previews) | Dynamic Island / full Live Activity behavior |
| App Intents & Shortcuts | Real thermal/battery context |
| WeatherKit (works on simulator with a simulated location) | True ambient conditions |

## 13. Final validation checklist (nothing above is "verified" until these pass)

```bash
xcodebuild build  -scheme AdaptiveHumanOS -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test   -scheme AdaptiveHumanOS -destination 'platform=iOS Simulator,name=iPhone 16'
```

then: run the widget in the simulator gallery · start an Eye Comfort
session and watch the Live Activity end by policy · grant/deny HealthKit
authorization and confirm graceful degradation both ways · trigger a
WeatherKit request and confirm the mapped conditions appear on the
dashboard.
