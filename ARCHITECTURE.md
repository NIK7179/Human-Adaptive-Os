# Architecture

## Layering

```
┌─────────────────────────────────────────────────────────┐
│ App/ (Xcode-only @main shell)                           │
├─────────────────────────────────────────────────────────┤
│ AdaptiveHumanOSUI (SwiftUI, #if canImport(SwiftUI))     │
│   DashboardView · WhyThisModeView · HistoryView         │
│   MoodCheckInView · PrivacyCenterView · SettingsView    │
│   DashboardViewModel (@Observable, @MainActor)          │
├─────────────────────────────────────────────────────────┤
│ AdaptiveExperienceKit (partner SDK concept)             │
├─────────────────────────────────────────────────────────┤
│ AdaptiveHumanOS (Foundation-only core — Linux testable) │
│   Models · Engine · Scores · Personalization ·          │
│   Simulation · History                                  │
└─────────────────────────────────────────────────────────┘
```

Dependency rule: the core knows nothing about SwiftUI or platform
frameworks. All Apple-framework access goes through protocols
(`AdaptiveClock`, `AdaptiveIDGenerating`, future `WeatherProviding`,
`HealthDataProviding`) with deterministic test implementations.

## The decision pipeline (Section B.2, ordered)

`TransparentAdaptiveDecisionEngine.evaluate(snapshot:preferences:history:)`:

1. Capture `evaluationTime = clock.now` **once** (B.23A timestamp policy).
2. `ContextSignalGenerator` derives `ContextSignal`s from the snapshot.
   Missing snapshot fields generate **no** signal — never a zero value.
3. Expired signals are filtered out and surfaced as `ignoredSignals`.
4. Signals are **sorted deterministically before vote generation and
   before summation** so processing order can never change a score
   (floating-point accumulation is order-sensitive; sorting removes the
   sensitivity).
5. Every signal casts weighted votes from the centralized
   `AdaptiveScoringConfiguration` table:
   `contribution = base × strength × reliability × preference × context`.
6. Per-mode sums → `LogisticScoreNormalizer` (never divide-by-max).
7. Exclusions (disabled modes) → stable ranking (normalized desc, raw
   desc, mode raw value).
8. `SignalContributionAnalyzer` derives independent/conflicting counts;
   `ContributionWeightedReliabilityCalculator` and `FreshnessCalculator`
   produce evidence-quality factors — all shared production types, all
   exercised directly by the keystone tests.
9. `ConfidenceCalculator` → evidence-coverage scaling for missing
   components (never renormalize the formula; below 0.65 coverage the
   result cannot exceed the suggestion threshold) → minimum-independent-
   signals cap (thin evidence never auto-applies).
10. `AdaptationOutcomeSelector` thresholds (0.60 / 0.72, both suggested at
    the edges) → hysteresis (`HysteresisPolicy`) → cooldown
    (`CooldownPolicy`, with the override-expiration rule) → manual
    override supremacy → user-preference gates.
11. Secondary `AdaptationModifiers` (accessibility/thermal/power) — these
    may change even during cooldown or override.
12. `DefaultThemeComposer` applies constraints in precedence order
    (platform > accessibility > safety > environment > thermal > explicit
    user > life mode > mode theme > learned aesthetics > decoration),
    recording every material override.
13. Explanation built from actual contributing votes, then validated:
    an adaptation without a valid explanation cannot ship.
14. Decision recorded to `AdaptationTimelineStore` (actor) with undo.

## Determinism contract

- No `Date()`, `UUID()`, `Calendar.current`, `TimeZone.current`,
  `Locale.current`, `Task.sleep` in core logic —
  `Core/Determinism.swift` is the single sanctioned home of system-backed
  implementations, and `DeterminismSourceScanTests` enforces it by
  scanning the source tree.
- `SequentialIDGenerator` (finite, exact) and `CountingIDGenerator`
  (unlimited, counter-encoded) provide reproducible IDs in tests.
- Semantic equality uses `AdaptationDecisionFingerprint` (rounded scores,
  no volatile IDs/timestamps), precision 1e-9.

## Calibration ground truth

The Section B.6A worked example is encoded twice on purpose:

- as the raw-number keystone fixture (`ConfidenceRegressionTests`), and
- as the `lateNightProlongedSession` simulation scenario, which drives the
  full engine to the same shape (Eye Comfort, 5 independent / 1
  conflicting signal, penalty 0.92, `.suggested`).

Two load-bearing constants to treat with respect:

- `conflictContributionThreshold = 0.10`: the worked example's
  positive-valence contribution (0.1260) sits just above it. Raising it to
  0.13 flips the fixture from `.suggested` to eligible-for-automatic.
- Logistic temperature 1.0: deliberately compresses strong scores so two
  well-supported modes route to a suggestion instead of a silent switch.
  Changing either requires recalculating the worked example, recalibrating
  every scenario, and updating fixtures in the same commit.

### Conflict-rule interpretation (documented deviation)

Section B.6A defines a conflicting signal as one that "materially opposes
the winner or supports another eligible mode", yet counts only positive
valence (not poor sleep, which also supports the eligible Recovery mode)
as conflicting. We therefore implement: a signal conflicts when its **net
winner contribution is negative** beyond the threshold, or when it does
not support the winner while materially supporting a competitor. A signal
that genuinely supports the winner is never a conflict. This is the only
reading consistent with `conflictingSignalCount = 1` in the worked
example, and is locked in by `SignalCountDerivationTests`.

## Error handling & degradation

Missing data degrades to fewer signals → lower evidence coverage → the
engine stays put and says why (`unavailableSignals`, "Not enough
information" comfort score). The `missingPermissions` and `noNetwork`
scenarios exercise these paths in tests and in the demo UI.
