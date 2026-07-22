// Xcode-only adapter — add to the iOS APP target (see App/XCODE_SETUP.md).
// Requires: HealthKit capability, NSHealthShareUsageDescription in
// Info.plist, and explicit user authorization on device. Read-only:
// this app never writes health data.
// NOT compiled or verified on Linux CI.

#if canImport(HealthKit)
import Foundation
import HealthKit
import AdaptiveHumanOS

/// `HealthDataProviding` backed by HealthKit.
///
/// Availability note (app deployment target is iOS 17):
/// - Sleep analysis and step count: available well before iOS 17 — no guards.
/// - State of Mind (`HKStateOfMind`): **iOS 18+ only.** Guarded with
///   `#available(iOS 18.0, *)`; on iOS 17 the method reports
///   `ProviderError.unavailable` and the engine degrades gracefully
///   (mood stays missing, never zero).
public final class HealthKitDataProvider: HealthDataProviding, @unchecked Sendable {
    private let store = HKHealthStore()
    private let clock: any AdaptiveClock
    private let calendar: Calendar

    public init(clock: any AdaptiveClock = SystemAdaptiveClock(), calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.clock = clock
        self.calendar = calendar
    }

    public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    public func requestReadAuthorization() async -> Bool {
        var readTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.quantityType(forIdentifier: .stepCount),
        ].compactMap { $0 }.reduce(into: []) { $0.insert($1) }
        if #available(iOS 18.0, *) {
            readTypes.insert(HKObjectType.stateOfMindType())
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    public func recentSleep() async throws -> SleepObservation {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw ProviderError.unavailable
        }
        let now = clock.now
        let windowStart = now.addingTimeInterval(-24 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: now)
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
                }
            }
            store.execute(query)
        }
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        let seconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        guard seconds > 0 else { throw ProviderError.unavailable }
        let hours = seconds / 3600.0
        let quality: SleepQuality
        switch hours {
        case ..<4.5: quality = .veryPoor
        case ..<6.0: quality = .poor
        case ..<7.0: quality = .fair
        case ..<8.5: quality = .good
        default: quality = .excellent
        }
        return SleepObservation(durationHours: hours, quality: quality, observedAt: now)
    }

    public func recentStateOfMind() async throws -> MoodObservation {
        guard #available(iOS 18.0, *) else {
            // iOS 17 fallback: State of Mind does not exist; report absence.
            throw ProviderError.unavailable
        }
        let now = clock.now
        let predicate = HKQuery.predicateForSamples(withStart: now.addingTimeInterval(-8 * 60 * 60), end: now)
        let samples: [HKStateOfMind] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.stateOfMindType(), predicate: predicate, limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKStateOfMind]) ?? [])
                }
            }
            store.execute(query)
        }
        guard let sample = samples.first else { throw ProviderError.unavailable }
        // HKStateOfMind valence is -1...1; the engine expects 0...1.
        let valence = (sample.valence + 1.0) / 2.0
        return MoodObservation(
            mood: nil,
            valence: min(max(valence, 0), 1),
            energy: nil,
            source: .healthKitStateOfMind,
            observedAt: sample.endDate
        )
    }

    public func todayActivity() async throws -> ActivityObservation {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw ProviderError.unavailable
        }
        let now = clock.now
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)
        let steps: Double = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                }
            }
            store.execute(query)
        }
        let level: ActivityLevel
        switch steps {
        case ..<1500: level = .sedentary
        case ..<5000: level = .light
        case ..<10000: level = .moderate
        default: level = .vigorous
        }
        return ActivityObservation(level: level, stepCount: Int(steps), observedAt: now)
    }
}
#endif
