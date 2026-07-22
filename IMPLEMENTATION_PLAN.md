# Adaptive Human OS — Implementation Plan

Status legend: ✅ implemented & test-covered · 🧪 implemented, verified by arithmetic replica + CI (no local toolchain) · 🎨 implemented as source, compiles only under Xcode/macOS (SwiftUI) · 📄 documented concept / blocked integration · ⛔ not started

## Environment constraints (read first)

This project was built in a Linux container **without a Swift toolchain** (all
Swift compiler distribution channels are blocked by the container network
policy). Mitigations, in order of strength:

1. **Platform-agnostic core.** All decision-engine logic lives in the
   `AdaptiveHumanOS` library target, which uses only `Foundation` and compiles
   on Linux, macOS and iOS. `swift test` exercises the whole engine.
2. **Exact arithmetic verification.** Every load-bearing constant in the
   keystone fixture and the worked example was replicated in IEEE-754 double
   arithmetic (same operation order as the Swift code) and matches the spec
   bit-for-bit (`overall = 0.6833730781418192`, diff `0.0`).
3. **CI compilation.** `.github/workflows/tests.yml` runs `swift test` in a
   `swift:6.1` container on every push, so the keystone fixture and the full
   suite compile and run on real toolchains.
4. **SwiftUI isolation.** Every UI file is wrapped in
   `#if canImport(SwiftUI)`, so `swift build`/`swift test` on Linux compile
   the package cleanly while Xcode builds the full UI.

## Phase plan

| Phase | Contents | Status |
|---|---|---|
| A | Keystone: signal→vote→score→confidence pipeline, outcome selector, regression fixture + gate tests | 🧪 |
| B | Full engine: scoring configuration, 19-stage pipeline, hysteresis, cooldown, manual overrides, theme composition, explainability + validation, timeline + undo, deterministic providers, comfort & fatigue scores, personalization, simulation scenarios, ≥35 engine tests | 🧪 |
| C1 | SwiftUI vertical slice: design system, dashboard, why-this-mode, history/undo, mood check-in, settings + simulation switcher, privacy center | 🎨 |
| C2 | Partner SDK `AdaptiveExperienceKit` + sample partner demo view | 🎨 |
| C3 | Docs: README, ARCHITECTURE, PRIVACY, APPLE_CAPABILITY_MATRIX, PARTNER_SDK, TESTING, PITCH_DEMO, ROADMAP | ✅ |
| D | Widgets, Live Activities, App Intents, HealthKit, WeatherKit, App Group, SwiftData persistence | 📄 blocked: needs Xcode targets, entitlements, signing (documented in README + capability matrix) |

## File tree

```
Package.swift
Sources/
  AdaptiveHumanOS/                  # platform-agnostic core (Foundation only)
    Core/
      Determinism.swift             # AdaptiveClock, ID generator, calendar/timezone/locale providers
    Models/
      AdaptiveMode.swift
      ContextSignal.swift           # kinds, sources, signal struct
      ModeVote.swift                # vote + ModeVoteCalculator
      ModeScore.swift               # score + LogisticScoreNormalizer
      Confidence.swift              # DecisionConfidence, configuration, calculator,
                                    # reliability calculator, outcome selector
      AdaptationOutcome.swift
      ContextSnapshot.swift         # snapshot + mood/sleep/weather/solar enums
      Preferences.swift             # AdaptivePreferences + personalization state
      Theme.swift                   # AdaptiveTheme, AdaptationModifiers, resolved theme,
                                    # override records, precedence levels
      AdaptationDecision.swift      # decision, fingerprint, intervention
      Timeline.swift                # timeline entry, user response, end reason
    Engine/
      EngineConfiguration.swift     # production/conservative/demo/unitTest
      ScoringConfiguration.swift    # centralized signal→mode vote table, reliability
                                    # defaults, freshness useful-ages, modifier rules
      SignalAnalysis.swift          # independent/conflicting derivation, freshness calc
      StabilityPolicies.swift       # hysteresis, cooldown, manual-override rules
      ThemeComposer.swift           # deterministic precedence-ordered composition
      Explainability.swift          # explanation, factors, builder, validator
      DecisionEngine.swift          # TransparentAdaptiveDecisionEngine (19 stages)
    Scores/
      ComfortScore.swift            # renormalizing score + missing-factor safeguards
      FatigueScore.swift            # interaction fatigue + 0.75 inferred cap
    Personalization/
      PreferenceLearning.swift      # bounded, smoothed weight adjustment + undo learning
    Simulation/
      SimulationScenario.swift      # 10 scenarios → snapshots the engine consumes
    History/
      AdaptationTimelineStore.swift # actor: timeline, undo, retention
  AdaptiveHumanOSUI/                # SwiftUI, all files #if canImport(SwiftUI)
    DesignSystem.swift
    ThemeEnvironment.swift
    AppRootView.swift
    DashboardView.swift
    DashboardViewModel.swift
    WhyThisModeView.swift
    HistoryView.swift
    MoodCheckInView.swift
    SettingsView.swift
    PrivacyCenterView.swift
    PreviewData.swift
  AdaptiveExperienceKit/            # partner SDK (no runtime injection)
    AdaptiveExperienceKit.swift
    PartnerDemoView.swift
Tests/
  AdaptiveHumanOSTests/
    ConfidenceRegressionTests.swift # THE KEYSTONE (verbatim fixture)
    NormalizationTests.swift
    ReliabilityCalculatorTests.swift
    ThresholdBoundaryTests.swift
    SignalCountDerivationTests.swift
    DeterminismSourceScanTests.swift# asserts no Date()/UUID() in scoring paths
    ScoringConfigurationTests.swift
    DecisionEngineTests.swift       # B.24 items 1–20
    StabilityPolicyTests.swift      # hysteresis/cooldown/override
    ExplainabilityTests.swift
    ComfortScoreTests.swift
    FatigueScoreTests.swift
    PersonalizationTests.swift
    SimulationScenarioTests.swift
    ThemeComposerTests.swift
    TimelineUndoTests.swift
App/                                # Xcode-only shell (not built by SwiftPM)
  AdaptiveHumanOSApp.swift          # @main consuming AppRootView
  XCODE_SETUP.md                    # numbered target/capability setup steps
.github/workflows/tests.yml
docs: README.md ARCHITECTURE.md PRIVACY.md APPLE_CAPABILITY_MATRIX.md
      PARTNER_SDK.md TESTING.md PITCH_DEMO.md ROADMAP.md
```

## Phase log

- **Phase 0 (repo inspection):** empty repo (README only). Branch
  `claude/adaptive-human-os-d0em02` checked out. No toolchain available;
  arithmetic replica verified all fixture constants exactly.
- **Phase A:** _in progress._
