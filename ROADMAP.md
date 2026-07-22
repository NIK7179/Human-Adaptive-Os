# Roadmap

## Phase 1 — Prototype (this repository)

Manual context + simulation, adaptive in-app UI, deterministic decision
engine with the keystone regression fixture, explainability + undo,
in-memory timeline with retention. **Done** (widgets deferred to Phase 2;
SwiftData adapter pending the Xcode target).

## Phase 2 — Permissioned intelligence

- SwiftData persistence for preferences, timeline, comfort patterns.
- WeatherKit (`WeatherProviding`), HealthKit sleep + State of Mind
  (`HealthDataProviding`) behind the existing protocol seams, with mocks
  kept for simulator use.
- Widget extension (small/medium + Lock Screen accessories) via App Group.
- Live Activities honoring `AdaptiveSessionPolicy` exit criteria (B.21):
  Focus, Eye Comfort, Interview Prep, Outdoor Visibility session rules; no
  permanent activities.
- App Intents: `ActivateAdaptiveModeIntent`, `GetCurrentModeIntent`,
  `LogMoodIntent`, `PauseAdaptationIntent`, `ResumeAdaptationIntent`,
  `StartInterviewPreparationIntent`, `StartEyeComfortIntent`,
  `ProvideAdaptationFeedbackIntent`.
- Contextual notification reminders (quiet hours, no retention nudges).

## Phase 3 — Personalization depth

Comfort Patterns ("You have previously preferred…" — correlation language
only, per-pattern delete, feature disable), Life Modes (Study, Work,
Recovery, Interview, Commute, Outdoor, Family, Vacation, Sleep prep, Deep
focus) with schedules and EventKit opt-in, Insights with Swift Charts,
onboarding flow (7 pages, contextual permission requests).

## Phase 4 — Research prototype

Apple Watch companion, optional physiological context, on-device model
experimentation, formal user studies, accessibility research,
battery/performance evaluation.

## Phase 5 — Platform proposal

System-level adaptive-theme API, cross-app participation contract,
privacy-preserving OS context broker, Apple partnership proposal — the
honest version of "adapt every app": the OS does it, apps opt in, the
user owns the data.
