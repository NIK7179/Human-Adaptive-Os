# Testing

```bash
swift test        # macOS or Linux, Swift 6.0+
```

CI (`.github/workflows/tests.yml`) runs the suite in a `swift:6.1`
container on every push.

## Suite map (~70 tests)

| File | Covers |
|---|---|
| `ConfidenceRegressionTests` | **THE KEYSTONE**: Eye Comfort fixture → `overall ≈ 0.6833730781418192`, `.suggested`; plus the B.6A wider-margin variation → `.applied` |
| `NormalizationTests` | Logistic closed-form match, bounds, monotonicity, compression intent |
| `ReliabilityCalculatorTests` | Production contribution-weighted reliability: abs weights, nil-not-zero, epsilon exclusion, clamping |
| `ThresholdBoundaryTests` | 0.60/0.72 edges (both inclusive → suggested), penalty floor, clamping |
| `SignalCountDerivationTests` | Derives independent = 5 and conflicting = 1 from five real `ContextSignal`s; kind-dedup; sub-threshold opposition; competitor-support rules |
| `DeterminismSourceScanTests` | No `Date()`/`UUID()`/`Calendar.current`/… outside `Core/Determinism.swift`; fixed clock and sequential IDs behave |
| `ScoringConfigurationTests` | Weight ranges, reliability ordering, worked-example weights encoded exactly, useful-age defaults, config variants |
| `DecisionEngineTests` | B.24 items 1–20: determinism (fingerprints), order-invariance, expiry, missing≠zero, mode-vote directions, confidence tiers, hysteresis, cooldown, overrides, visibility bypass, explicit-vs-inferred mood, modifiers, valid explanations, no diagnostic language, stable ordering, disabled modes, automatic-off downgrade |
| `StabilityPolicyTests` | Hysteresis margins, cooldown durations, override-expiration rule (stale cooldown ignored), engine-level post-override freedom |
| `ThemeComposerTests` | Precedence: accessibility over Calm, thermal strips animation, environment raises contrast, determinism, no-op passthrough |
| `ExplainabilityTests` | Validator: empty prose, missing factors, missing undo, source mismatch, claiming unused sources, prohibited terms |
| `ComfortScoreTests` | Proportional renormalization, min-factor/coverage/share safeguards, reliability ladder, suppression rules |
| `FatigueScoreTests` | 0.75 inferred cap (computed-then-capped), explicit exceeds cap, nil-not-zero, level bands |
| `PersonalizationTests` | Single-event smoothing, min samples, bounded band 0.75…1.25, reset, disable |
| `SimulationScenarioTests` | Expected leader per scenario, simulated-source labeling, graceful degradation, polar solar handling |
| `TimelineUndoTests` | Undo restores mode + invalidates cooldown + smoothed learning step, suggestion ≠ mode change, override lifecycle, retention, delete-all, feedback |

## Verification without a local toolchain

This repository was authored in a Linux container with no Swift compiler
available (network policy blocks all toolchain distribution channels).
Compensations, in order of strength:

1. Every constant in the keystone and the B.6A worked example was
   replicated in exact IEEE-754 double arithmetic with the same operation
   order (`overall` matched to the last bit: diff 0.0).
2. All Swift files parse cleanly under tree-sitter's Swift grammar.
3. CI compiles and runs the full suite on push.

## Floating-point tolerance policy (A.11)

Fixtures use `1e-6`. Raise to `1e-5` only for a demonstrated
accumulation-order difference, with a code comment naming it, and never
merely to make a failing test pass.

## UI tests (planned, Xcode target)

Onboarding completion, mood logging, manual mode activation, opening
"Why this mode?", feedback, scenario switching, data deletion — to be
added as an `AdaptiveHumanOSUITests` target when the Xcode shell exists.
