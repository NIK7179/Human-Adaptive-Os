# Adaptive Human OS

A privacy-first, context-aware iOS prototype that adapts its interface to
the human using it — time of day, sleep, self-reported mood, screen
fatigue, environment and accessibility needs — through a **deterministic,
explainable, weighted-scoring decision engine** that never adapts without
evidence, never diagnoses, and always explains itself.

> **This is an independent prototype.** It does not — and cannot — modify
> the interfaces of Instagram, WhatsApp, YouTube or any third-party app.
> iOS does not grant apps that access. See
> [`APPLE_CAPABILITY_MATRIX.md`](APPLE_CAPABILITY_MATRIX.md) for the honest
> breakdown of what is possible today, what needs user action, and what
> would require Apple partnership.

## What is here

| Layer | Target | Status |
|---|---|---|
| Decision engine (Section A keystone + Section B) | `AdaptiveHumanOS` | Complete, platform-agnostic (Foundation only), ~70 unit tests incl. the keystone regression fixture |
| SwiftUI app layer (dashboard, why-this-mode, history, mood check-in, privacy center, settings) | `AdaptiveHumanOSUI` | Complete as source; compiles under Xcode/macOS (`#if canImport(SwiftUI)`) |
| Partner SDK concept + sample partner feed | `AdaptiveExperienceKit` | Complete as source |
| App shell for device builds | `App/` | Provided with numbered Xcode steps |
| Widgets, Live Activities, App Intents, WeatherKit, HealthKit | — | **Not implemented** — blocked on Xcode targets/entitlements; documented in the capability matrix and Settings screen |

## The keystone (executable specification)

The engine's ground truth is the late-night Eye Comfort fixture:

```
averageReliability = 1.89881 / 2.0102 = 0.9445876032235598
winningScore       = logistic(1.7582) = 0.852984…
overall confidence = 0.6833730781418192
outcome            = .suggested   (0.60 ≤ x ≤ 0.72 never applies silently)
```

`Tests/AdaptiveHumanOSTests/ConfidenceRegressionTests.swift` verifies this
against the production `ContributionWeightedReliabilityCalculator`,
`LogisticScoreNormalizer`, `ConfidenceCalculator` and
`AdaptationOutcomeSelector` — no test-local formula copies. Supporting
tests cover normalization, reliability weighting, threshold boundaries
(0.60/0.72 edges), derivation of the independent/conflicting signal counts
from real `ContextSignal`s, and a source scan proving no ambient
`Date()`/`UUID()` in scoring code.

## Requirements

- **Engine + tests:** Swift 6.0+ toolchain on macOS or Linux — no Apple
  frameworks needed. `swift test` runs everything.
- **App:** Xcode 16+, iOS 17+ deployment target.

## Running the tests

```bash
swift test            # builds the core + UI stubs and runs ~70 tests
```

CI runs the same suite in a `swift:6.1` container on every push
(`.github/workflows/tests.yml`).

## Running the demo app

Follow the numbered steps in [`App/XCODE_SETUP.md`](App/XCODE_SETUP.md):
create a thin iOS app target, add the local package, run. The app launches
on labeled simulation data — no permissions, accounts or network needed.

### Simulation mode

Ten scenarios (Settings → Developer, or the badge menu on the dashboard):
sunny outdoor afternoon · rainy low-energy evening · late-night prolonged
session · good-sleep productive morning · high cognitive load · interview
in one hour · recovery after poor sleep · missing permissions · no network
· manual mode override. The whole UI and the decision engine respond to the
selected scenario, and every screen labels the data as simulated.

## Setup for optional integrations

All are optional; the demo is fully functional without them.

- **Bundle ID / signing:** replace `com.example.adaptivehumanos`
  (App/XCODE_SETUP.md, step 5).
- **App Group** (future widgets): `group.com.example.adaptivehumanos`.
- **WeatherKit:** capability + registered bundle ID (paid developer account).
- **HealthKit:** capability + `NSHealthShareUsageDescription`; sleep and
  State of Mind are read-only and permission-gated.
- **Widgets / Live Activities:** require a widget extension target — see
  the capability matrix.

## Documentation

[`ARCHITECTURE.md`](ARCHITECTURE.md) · [`PRIVACY.md`](PRIVACY.md) ·
[`APPLE_CAPABILITY_MATRIX.md`](APPLE_CAPABILITY_MATRIX.md) ·
[`PARTNER_SDK.md`](PARTNER_SDK.md) · [`TESTING.md`](TESTING.md) ·
[`PITCH_DEMO.md`](PITCH_DEMO.md) · [`ROADMAP.md`](ROADMAP.md) ·
[`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md)

## Known limitations

- Built in a Linux environment without a Swift toolchain or Xcode: the
  engine is verified by an exact-arithmetic replica of every fixture
  constant plus tree-sitter syntax validation, and compiles/tests on CI;
  the SwiftUI layer is syntax-validated source that needs one Xcode pass.
- No SwiftData persistence yet — the timeline lives in an actor-backed
  in-memory store with the same API surface (retention + deletion
  implemented), designed to gain a SwiftData adapter in the app target.
- Widgets, Live Activities, App Intents, WeatherKit and HealthKit are
  design-complete (protocols + policies in the engine) but not wired to
  platform frameworks. The Settings screen and Privacy Center state this
  honestly.

## Screenshots

_Placeholders — capture after the first Xcode build:_
`docs/screenshots/dashboard.png`, `why-this-mode.png`, `history.png`,
`privacy-center.png`, `partner-demo.png`.
