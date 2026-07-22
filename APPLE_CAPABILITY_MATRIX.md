# Apple capability matrix

An honest map of what this concept can do at each level of platform
access. **The app never pretends the third category already works.**

## 1. Available to this prototype today (public APIs)

| Capability | Status in repo |
|---|---|
| Fully adaptive interface inside our own app | Implemented (`AdaptiveHumanOSUI`) |
| Deterministic decision engine with explainability | Implemented (`AdaptiveHumanOS`) |
| Simulation mode for every scenario | Implemented |
| Partner-SDK theme adoption for participating apps | Implemented as concept (`AdaptiveExperienceKit`) |
| Home/Lock Screen widgets (WidgetKit) | Designed, not built — needs widget extension + App Group |
| Live Activities with strict exit criteria (B.21 `AdaptiveSessionPolicy`) | Policy types designed; extension not built |
| App Intents & Shortcuts | Designed (intent list in ROADMAP), not built |
| WeatherKit / permissioned HealthKit (sleep, State of Mind) | Protocol seams ready; entitlements documented |
| Local notifications, background refresh at permitted intervals | Not built; policies documented (no silent audio, no polling abuse) |

## 2. Possible only with user action / limited APIs

- Focus workflows (user configures a Focus that runs our Shortcut).
- Opening system settings via approved deep links (user confirms).
- Selecting/saving a wallpaper (user action).
- Screen Time controls (FamilyControls entitlement + user authorization).
- Changing certain accessibility preferences (user does it in Settings; we
  read the public values as constraints).

## 3. Requires Apple / OS partnership (explicitly NOT claimed)

- Automatically restyling every installed app; modifying Instagram or
  WhatsApp layouts.
- System-wide typography replacement or animation changes in other apps.
- Silent system-wide brightness/contrast orchestration beyond public APIs.
- Universal notification reprioritization.
- Reading activity in another app; system-wide emotional inference.

The Phase 5 proposal (ROADMAP) sketches what a real OS-level
adaptive-theme API and privacy-preserving context broker could look like —
as a proposal to Apple, not as shipped behavior.
