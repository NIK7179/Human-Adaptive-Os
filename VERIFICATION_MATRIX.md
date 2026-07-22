# Verification matrix

Statuses:
**Linux compiled and tested** (runs on CI, `swift test`) ·
**Syntax-only** (parses; never compiled anywhere) ·
**Requires Xcode compilation** · **Requires entitlement** ·
**Requires physical device** · **Requires user authorization** ·
**Not implemented**

Conditional-compilation-guarded code is never described as verified.
Final validation for everything below the first section requires:
`xcodebuild build`, `xcodebuild test`, widget preview/simulator execution,
Live Activity execution, HealthKit authorization testing, and a WeatherKit
request test (App/XCODE_SETUP.md step 13).

## Core engine & services (Sources/, Tests/)

| Component | Status |
|---|---|
| Keystone pipeline + regression fixture (Section A) | **Linux compiled and tested** ✅ |
| Decision engine, 19-stage pipeline, hysteresis/cooldown/overrides (Section B) | **Linux compiled and tested** ✅ |
| Theme composition, explainability + validation, timeline + undo | **Linux compiled and tested** ✅ |
| Comfort & fatigue scores, personalization, 10 simulation scenarios | **Linux compiled and tested** ✅ |
| Provider protocols (`WeatherProviding`, `HealthDataProviding`, `AmbientContextProviding`, `InteractionFatigueProviding`, `NotificationProviding`) | **Linux compiled and tested** ✅ |
| Simulation-backed providers + `ContextSnapshotAssembler` (missing permissions, stale, partial, failures, cancellation, deterministic timestamps, no-network) | **Linux compiled and tested** ✅ |
| Live Activity exit policies (`AdaptiveSessionPolicy`, `SessionExitEvaluator`) | **Linux compiled and tested** ✅ |
| App Group shared-state codec (`SharedAdaptiveState`, `SharedStateSerializer`) | **Linux compiled and tested** ✅ |

## SwiftUI layer (Sources/AdaptiveHumanOSUI, AdaptiveExperienceKit views)

| Component | Status |
|---|---|
| Dashboard, Why-this-mode, History, Mood check-in, Privacy Center, Settings | Syntax-only · **Requires Xcode compilation** (compiles to empty module on Linux via `#if canImport(SwiftUI)`) |
| Partner demo view | Syntax-only · **Requires Xcode compilation** |

## Xcode-target sources (App/XcodeTargets/)

| Component | Status |
|---|---|
| `WeatherKitWeatherProvider` | Syntax-only · Requires Xcode compilation + **WeatherKit entitlement** (paid account) + **user authorization** (location) |
| `HealthKitDataProvider` | Syntax-only · Requires Xcode compilation + **HealthKit entitlement** + **user authorization**; State of Mind additionally iOS 18+ and effectively a **physical device** |
| `SystemAmbientContextProvider` | Syntax-only · Requires Xcode compilation (public APIs only, no entitlement) |
| `UserNotificationCenterProvider` | Syntax-only · Requires Xcode compilation + **user authorization** |
| `AppGroupStateStore` | Syntax-only · Requires Xcode compilation + **App Group entitlement** on app and extension |
| Home Screen & Lock Screen widgets | Syntax-only · Requires Xcode compilation (widget extension) + App Group |
| Eye Comfort / Focus Live Activities | Syntax-only · Requires Xcode compilation + `NSSupportsLiveActivities`; full behavior **requires physical device** |
| App Intents & Shortcuts | Syntax-only · Requires Xcode compilation |

## Not implemented (deliberately)

| Item | Why |
|---|---|
| SwiftData persistence | Next phase; actor store has the API surface, retention and deletion |
| Onboarding flow, Life Modes, Insights charts, Comfort Patterns UI | Phase 3 scope (ROADMAP) |
| Background refresh scheduling (BGTaskScheduler) | Needs app target + device testing to be honest about behavior |
| Real third-party app integrations | Impossible on iOS by design; the voluntary partner SDK is the honest equivalent (APPLE_CAPABILITY_MATRIX) |
| Apple-partnership system features | Documented as proposals only |
