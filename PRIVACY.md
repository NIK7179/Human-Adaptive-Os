# Privacy

## Principles

1. **On-device by default.** The decision engine, personalization and all
   scores run locally. The MVP has no backend, no accounts, no analytics,
   no third-party SDKs. The only future network call is WeatherKit, and it
   is optional.
2. **Data minimization.** The engine consumes normalized signals, not raw
   streams. Nothing stores exact location history, raw health samples
   beyond the current evaluation, or journal text unless deliberately
   saved.
3. **Explicit consent, purpose limitation, revocability.** Every sensor or
   permission is requested in context, explained in plain language, usable
   in denial, and revocable with graceful degradation.
4. **No hidden mood inference.** Mood enters the system three ways only:
   a manual check-in, HealthKit State of Mind (explicit permission), or an
   opt-in, in-app-only interaction estimate that is off by default,
   labeled as an estimate everywhere it appears, and carries reduced
   reliability in scoring.
5. **No diagnosis, ever.** The explanation validator rejects any generated
   text containing diagnostic language (depression, anxiety, ADHD,
   insomnia, clinical terms…). The comfort score is labeled an *estimated
   interface-comfort score*; the fatigue score describes in-app
   interaction only, never neurological fatigue. This is enforced by unit
   tests, not just policy.
6. **No dark patterns.** No streaks, no gamified emotional health, no
   retention notifications, no manipulation of the confidence numbers.
   When evidence is weak the app says "not enough information".

## What the prototype accesses today

| Source | State | Notes |
|---|---|---|
| Simulation scenarios | Active | All data labeled `isSimulated`, sources reported as `simulation` |
| Manual mood check-in | Local only | Valence/energy/tags; note field stays on device |
| In-app session activity | Opt-in, off by default | Only this app's usage; never other apps, keyboards, microphone, camera |
| HealthKit, WeatherKit, Location | Not connected | Protocol seams exist; entitlements documented in App/XCODE_SETUP.md |

## Explainability as a privacy feature

Every decision carries: the factors used (with source and
approximation flags), the sources *not* used, signals ignored as expired,
data that was unavailable, a privacy summary, and undo instructions.
`ExplanationValidator` fails any decision whose stated sources do not
match the votes that actually contributed — the explanation cannot lie.

## Retention & deletion

- Timeline retention windows: off / 7 / 30 / 90 days
  (`AdaptationTimelineStore.applyRetention`).
- "Reset learned preferences" and "Delete all adaptation history" are
  one-tap operations in Settings and the Privacy Center.

## Privacy manifest (for the device build)

When creating the Xcode target, add `PrivacyInfo.xcprivacy` declaring:
no tracking, no required-reason API usage beyond UserDefaults
(CA92.1: app-own data), and data collection: none leaving the device.
