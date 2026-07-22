# Five-minute pitch demo

Run the app from Xcode (App/XCODE_SETUP.md). Everything below works on
simulation data with zero permissions.

**0:00 — Normal dashboard.** Launch. Settings → Developer → scenario
**Good-sleep productive morning**. Back to Today: Energize is active with
high confidence, the meter and "Why this mode?" are visible. Point out the
simulation badge — nothing here is hidden.

**0:40 — Simulate late-night fatigue.** Switch the scenario to
**Late-night prolonged session** (the dashboard badge menu). This is the
exact worked example from the engine spec: 11:24 PM, 68-minute session,
five hours of sleep, low energy, positive mood.

**1:10 — The UI adapts — by asking, not by force.** A suggestion banner
appears: *"Eye Comfort might help right now."* Confidence lands at ~68% —
inside the suggest band (60–72%), so the app **asks** instead of switching
silently. Tap **Switch to Eye Comfort**: the whole dashboard re-themes
warm and dim with reduced motion.

**1:50 — Why?** Open **Why this mode?**. Walk the factors: late night
(+0.74), long session (+0.48), low energy (+0.40), short sleep (+0.27) —
and the honest counter-evidence: positive mood (−0.13) applied a 0.92
conflict penalty. Show the confidence breakdown, unavailable data, sources
used, and the undo instructions.

**2:30 — Correct it.** Tap **Undo**. The previous mode returns instantly,
History records "You undid it", and the engine takes a smoothed learning
step — one correction never blacklists a mode.

**3:00 — Lock Screen & Live Activity (concept).** Show the capability
matrix: widgets and Live Activities are designed with strict exit criteria
(no permanent activities), pending a widget extension target. [If the
extension is built by demo day: show the Lock Screen widget and start an
Eye Comfort session here instead.]

**3:30 — Partner demo.** Open the **Partner demo** tab. Toggle theme
adoption: the mock partner feed dims media and loosens density under Eye
Comfort. This is the voluntary SDK path — no runtime injection, no claims
about Instagram or WhatsApp.

**4:10 — Privacy Center.** Every source with its true state, what is
stored (counts on screen), one-tap delete, and the "what this app never
does" list — including *never diagnoses mood or mental health*, enforced
by a validator that rejects diagnostic language in generated explanations.

**4:40 — The ask.** The capability matrix, category 3: system-wide
adaptation — restyling every app, universal notification reprioritization,
an OS context broker — requires Apple. This prototype is the working proof
of the decision layer: deterministic, explainable, threshold-gated,
privacy-first. That is the partnership proposal.
