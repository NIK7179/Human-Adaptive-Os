// Xcode-only adapter — add to the iOS APP target (see App/XCODE_SETUP.md).
// Requires user notification authorization (requested in context, after
// the UI explains the value). Gentle reminders only — never retention
// nudges, never quiet-hours violations.
// NOT compiled or verified on Linux CI.

#if canImport(UserNotifications)
import Foundation
import UserNotifications
import AdaptiveHumanOS

/// `NotificationProviding` backed by `UNUserNotificationCenter`. All APIs
/// used are available at the iOS 17 deployment target.
public final class UserNotificationCenterProvider: NotificationProviding, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()
    /// Local quiet hours (default 22:00–08:00): reminders that would fire
    /// inside the window are pushed to its end.
    public let quietHoursStart: Int
    public let quietHoursEnd: Int
    private let clock: any AdaptiveClock
    private let calendar: Calendar

    public init(
        quietHoursStart: Int = 22,
        quietHoursEnd: Int = 8,
        clock: any AdaptiveClock = SystemAdaptiveClock(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.clock = clock
        self.calendar = calendar
    }

    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func schedule(_ reminder: ScheduledReminder) async throws {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            throw ProviderError.permissionDenied
        }
        var fireAfter = reminder.fireAfter
        let fireDate = clock.now.addingTimeInterval(fireAfter)
        let hour = calendar.component(.hour, from: fireDate)
        let inQuietHours = quietHoursStart > quietHoursEnd
            ? (hour >= quietHoursStart || hour < quietHoursEnd)
            : (hour >= quietHoursStart && hour < quietHoursEnd)
        if inQuietHours && reminder.kind != .sleepPreparation {
            // Defer to the end of quiet hours instead of interrupting rest.
            let hoursUntilEnd = (quietHoursEnd - hour + 24) % 24
            fireAfter += TimeInterval(hoursUntilEnd) * 3600
        }
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = nil   // gentle by default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(fireAfter, 60), repeats: false)
        // One reminder per kind: same identifier replaces the previous one.
        let request = UNNotificationRequest(
            identifier: "adaptive.reminder.\(reminder.kind.rawValue)",
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    public func cancelReminder(kind: AdaptiveReminderKind) async {
        center.removePendingNotificationRequests(withIdentifiers: ["adaptive.reminder.\(kind.rawValue)"])
    }

    public func cancelAllReminders() async {
        let ids = AdaptiveReminderKind.allCases.map { "adaptive.reminder.\($0.rawValue)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
#endif
