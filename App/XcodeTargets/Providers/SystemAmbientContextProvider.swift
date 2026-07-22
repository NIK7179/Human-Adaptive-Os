// Xcode-only adapter — add to the iOS APP target (see App/XCODE_SETUP.md).
// PUBLIC APIs ONLY: screen brightness + clock-based solar approximation.
// There is no public ambient-light-sensor API on iOS, and this provider
// does not pretend otherwise — every reading is flagged `isApproximation`.
// NOT compiled or verified on Linux CI.

#if canImport(UIKit)
import Foundation
import UIKit
import AdaptiveHumanOS

/// `AmbientContextProviding` from public signals only:
/// - `UIScreen.brightness` (a weak proxy for surroundings; approximation),
/// - a clock-hour solar approximation (`solarPhase` reported honestly as an
///   approximation-derived value; a future CoreLocation sunrise/sunset
///   model can replace it without touching the engine),
/// - a user-selectable indoors/outdoors hint owned by the app UI.
///
/// All APIs used are available at the iOS 17 deployment target — no
/// additional availability guards required.
public final class SystemAmbientContextProvider: AmbientContextProviding, @unchecked Sendable {
    private let clock: any AdaptiveClock
    private let calendar: Calendar
    /// UI-owned hint ("I'm outdoors"); nil when the user never said.
    public var userReportedOutdoors: Bool?

    public init(clock: any AdaptiveClock = SystemAdaptiveClock(), calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.clock = clock
        self.calendar = calendar
    }

    public func currentAmbientContext() async throws -> AmbientObservation {
        let now = clock.now
        let hour = calendar.component(.hour, from: now)
        let brightness = await MainActor.run { UIScreen.main.brightness }

        let ambient: AmbientLightCategory?
        switch brightness {
        case ..<0.15: ambient = .veryDark
        case ..<0.35: ambient = .dim
        case ..<0.85: ambient = .indoor
        default: ambient = userReportedOutdoors == true ? .directSunlight : .bright
        }

        // Clock-based approximation until a solar model with location
        // permission replaces it (Section B.14 fallback rule).
        let phase: SolarPhase
        switch hour {
        case 0..<5, 22...23: phase = .night
        case 5..<7: phase = .civilTwilightMorning
        case 7..<11: phase = .morning
        case 11..<14: phase = .solarNoon
        case 14..<18: phase = .afternoon
        case 18..<22: phase = .civilTwilightEvening
        default: phase = .unavailable
        }

        return AmbientObservation(
            ambientLight: ambient,
            likelyOutdoors: userReportedOutdoors,
            solarPhase: phase,
            isApproximation: true,
            observedAt: now
        )
    }
}
#endif
