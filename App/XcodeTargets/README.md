# Xcode-target sources (NOT built by SwiftPM, NOT verified on Linux)

Everything in this folder tree requires compilation inside an Xcode target
on macOS. The Linux package deliberately does not reference these files —
they exist here so that creating the targets (steps in `../XCODE_SETUP.md`)
is a drag-in operation, not a writing session.

| Folder | Add to target | Status |
|---|---|---|
| `Providers/` | iOS app target | Syntax-only · requires Xcode compilation (+ entitlements per file) |
| `Shared/` | App target **and** widget extension | Syntax-only · requires App Group entitlement |
| `Widgets/` | Widget Extension target | Syntax-only · requires Xcode compilation |
| `LiveActivities/` | Widget Extension target | Syntax-only · requires Xcode compilation + physical device for full behavior |
| `AppIntents/` | iOS app target | Syntax-only · requires Xcode compilation |

Every file is wrapped in `#if canImport(...)` so an accidental inclusion in
a non-Apple build compiles to nothing rather than failing. That guard is a
safety net, **not** a claim of verification: none of this code has been
compiled anywhere yet. Final validation requires `xcodebuild build`,
`xcodebuild test`, widget/simulator execution, Live Activity execution on
a device, HealthKit authorization testing, and a WeatherKit request test.
