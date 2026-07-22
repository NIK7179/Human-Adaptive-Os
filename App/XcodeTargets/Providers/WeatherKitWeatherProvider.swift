// Xcode-only adapter — add to the iOS APP target (see App/XCODE_SETUP.md).
// Requires: WeatherKit capability, registered bundle ID (paid developer
// account), and location permission for local forecasts.
// NOT compiled or verified on Linux CI.

#if canImport(WeatherKit) && canImport(CoreLocation)
import Foundation
import WeatherKit
import CoreLocation
import AdaptiveHumanOS

/// `WeatherProviding` backed by Apple WeatherKit. Deployment target is
/// iOS 17, and every WeatherKit API used here is available since iOS 16 —
/// no additional availability guards are required.
public final class WeatherKitWeatherProvider: NSObject, WeatherProviding, CLLocationManagerDelegate, @unchecked Sendable {
    private let service = WeatherService.shared
    private let manager = CLLocationManager()
    private let clock: any AdaptiveClock

    public init(clock: any AdaptiveClock = SystemAdaptiveClock()) {
        self.clock = clock
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer   // data minimization
    }

    public func currentWeather() async throws -> WeatherObservation {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw ProviderError.permissionDenied
        case .notDetermined:
            // Never prompt from a background fetch; the app asks in context.
            throw ProviderError.permissionDenied
        default:
            break
        }
        guard let location = manager.location else { throw ProviderError.unavailable }
        do {
            let current = try await service.weather(for: location, including: .current)
            return WeatherObservation(
                weather: WeatherContext(
                    condition: Self.mapCondition(current.condition),
                    temperatureCelsius: current.temperature.converted(to: .celsius).value,
                    isPrecipitating: current.precipitationIntensity.value > 0,
                    uvIndex: current.uvIndex.value
                ),
                observedAt: clock.now
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            throw ProviderError.networkUnavailable
        } catch {
            throw ProviderError.unavailable
        }
    }

    static func mapCondition(_ condition: WeatherCondition) -> AdaptiveHumanOS.WeatherCondition {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return .clear
        case .partlyCloudy, .mostlyCloudy:
            return .partlyCloudy
        case .cloudy, .haze, .smoky:
            return .overcast
        case .drizzle, .rain, .heavyRain, .sunShowers, .freezingDrizzle, .freezingRain:
            return .rain
        case .snow, .flurries, .heavySnow, .sleet, .blizzard, .blowingSnow, .sunFlurries, .wintryMix:
            return .snow
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms,
             .hurricane, .tropicalStorm:
            return .storm
        case .foggy:
            return .fog
        default:
            return .unknown
        }
    }
}
#endif
