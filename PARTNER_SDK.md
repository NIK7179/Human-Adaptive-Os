# AdaptiveExperienceKit — partner SDK concept

Shows how a participating app could **voluntarily** adopt the user's
current adaptive context. It performs no runtime injection and cannot
touch apps that do not link it.

## Contract

```swift
import AdaptiveExperienceKit

// What a partner receives — presentation intent only. No mood values,
// no health data, no location ever crosses the boundary.
let context: AdaptiveExperienceContext   // mode + theme + isSimulated

// Adoption is one modifier:
MyFeedView()
    .adaptiveExperience(context.theme)
```

`AdaptiveExperienceTheme` carries: background style, contrast level, font
scale, line spacing, motion intensity, animation duration multiplier,
visual complexity, media intensity (0…1) and content density (0…1).
Partners map those to their own design systems — colors, typography,
spacing, motion, autoplay behavior, feed density.

`AdaptiveExperienceProviding` is the delivery seam. In this prototype a
`StaticAdaptiveExperienceProvider` feeds the demo; in a real deployment
the host app would publish the current context through an App Group and
partners would read it (both apps opt in; the user controls the toggle).

## The demo

The **Partner demo** tab renders a mock partner feed with a live toggle:
adopt the Adaptive Human OS theme or stay neutral. When Eye Comfort or Low
Stimulation is active, the mock feed minimizes media previews and loosens
density — exactly the behavior a real partner would implement.

## Boundaries

- No mechanism in this SDK can modify an app that hasn't linked it.
- The theme bridge (`AdaptiveExperienceTheme(from:)`) deliberately drops
  everything except presentation tokens.
- `isSimulated` is part of the contract so partners can label demo data
  exactly like the host app does.
