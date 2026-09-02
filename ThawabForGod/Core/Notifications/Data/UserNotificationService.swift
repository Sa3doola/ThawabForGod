//
//  UserNotificationService.swift
//  ThawabForGod
//

import Foundation
import UserNotifications

/// Permission, and the rolling window of prayer reminders, on top of the notification centre.
///
/// It holds no rules of its own. The window's arithmetic is `PrayerReminderPlanner`'s, the state
/// of the world is `ReminderInputsProviding`'s, and the words are `ReminderContentProviding`'s;
/// what is left here is the translation into `UNNotificationRequest` and the order of
/// operations. That split is what lets the interesting half be tested as pure Swift.
///
/// `@MainActor` is a claim rather than a habit: the type is driven from the UI — onboarding's
/// prompt, the scene phase, Settings — and it holds the notification centre, whose permission
/// prompt is user interface. Nothing here is long enough to be worth moving off: the planning is
/// a few dozen solar-angle calculations, and the `add` calls are awaits on the system rather
/// than work on this thread.
@MainActor
final class UserNotificationService: NotificationService {
    private let center: any NotificationCenterClient
    private let planner: PrayerReminderPlanner
    private let content: any ReminderContentProviding
    private let inputs: any ReminderInputsProviding

    /// The banner's thumbnail. Optional in effect rather than in type — see `artwork(for:)`.
    private let artwork: any ReminderArtworkProviding
    private let now: @Sendable () -> Date

    /// Gregorian and in the user's zone, to match the engine that produced the times — the
    /// trigger's components are read back out with this, so a device on the Islamic calendar
    /// cannot hand `UNCalendarNotificationTrigger` a Hijri year.
    private let calendar: Calendar

    /// - Parameter center: not defaulted, for the reason `AppContainer` does not default its
    ///   `CLLocationManager` either — reaching for `UNUserNotificationCenter.current()` touches
    ///   the system, and a default argument would do it even for a caller supplying a fake.
    init(
        center: any NotificationCenterClient,
        planner: PrayerReminderPlanner,
        content: any ReminderContentProviding,
        inputs: any ReminderInputsProviding,
        artwork: any ReminderArtworkProviding,
        timeZone: TimeZone = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.center = center
        self.planner = planner
        self.content = content
        self.inputs = inputs
        self.artwork = artwork
        self.now = now

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    // MARK: Permission

    func authorizationStatus() async -> NotificationAuthorization {
        NotificationAuthorization(await center.authorizationStatus())
    }

    @discardableResult
    func requestAuthorization() async -> NotificationAuthorization {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .authorized : .denied
        } catch {
            // The system throws when it cannot even ask — an unsigned build, or a device
            // policy. Reminders are optional, so this degrades rather than propagates.
            return .denied
        }
    }

    // MARK: Scheduling

    func refreshSchedule() async {
        // Idempotent, and free. Registering here rather than from a trigger of its own is the
        // same call `refillReminders()` makes about widget reloads: a second launch-time trigger
        // would be a second thing to keep in step, and the failure when the two drifted would be
        // a delivered notification falling back to the system's layout with nobody able to say
        // why. The categories are what tell iOS to hand a notification to the content extension.
        center.setCategories(ReminderCategory.registrations)

        guard await authorizationStatus() == .authorized else {
            // Permission can be taken away in the Settings app between launches. Clearing here
            // means the pending window does not sit there waiting for it to come back.
            cancelAll()
            return
        }

        let inputs = await inputs.currentInputs()

        guard let coordinates = inputs.coordinates else {
            cancelAll()
            return
        }

        // Planned before anything is cleared, so a failure to compute leaves the existing
        // window in place rather than replacing it with nothing.
        let reminders = planner.reminders(
            from: now(),
            coordinates: coordinates,
            config: inputs.config,
            enabled: inputs.enabledPrayers
        )

        cancelAll()

        // Sequentially, and deliberately: these are handoffs to the system rather than work
        // this thread does, fifty of them cost nothing worth parallelising, and doing them in
        // order keeps the failure of one from being interleaved with the rest.
        for reminder in reminders {
            // A single rejected request is not worth abandoning the other forty-nine for.
            try? await center.add(request(for: reminder))
        }
    }

    func cancelAll() {
        center.removeAllPendingRequests()
    }

    // MARK: Translation

    private func request(for reminder: PrayerReminder) -> UNNotificationRequest {
        let text = content.content(for: reminder)

        let notification = UNMutableNotificationContent()
        notification.title = text.title
        notification.subtitle = text.subtitle
        notification.body = text.body
        notification.sound = .default

        // What routes a delivered notification to the content extension, which declares the same
        // identifier in its `Info.plist`.
        notification.categoryIdentifier = text.category.identifier
        notification.userInfo = text.presentation.userInfo

        // The banner's thumbnail. Attached last and swallowed on failure: a reminder without its
        // picture is still a reminder, and losing the reminder to save the picture is the wrong
        // trade.
        if let url = artwork.artwork(for: reminder.prayer) {
            if let attachment = try? UNNotificationAttachment(
                identifier: "artwork", url: url, options: nil
            ) {
                notification.attachments = [attachment]
            } else {
                // The provider hands back a fresh file each time, because a successful attachment
                // *moves* it into the system's store — so an unsuccessful one leaves it behind,
                // and fifty of those per refresh is a directory nobody owns.
                try? FileManager.default.removeItem(at: url)
            }
        }

        // Calendar components rather than a time interval, so a reminder scheduled for next
        // Tuesday still lands at Maghrib if the clock changes for daylight saving in between.
        // Non-repeating: every occurrence is its own request, because the times move daily.
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminder.date
        )

        return UNNotificationRequest(
            identifier: reminder.id,
            content: notification,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }
}

// MARK: - UserNotifications to domain

nonisolated private extension NotificationAuthorization {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        // Provisional delivers quietly to the notification centre, which is still enough for
        // prayer reminders to be useful.
        case .authorized, .provisional, .ephemeral:
            self = .authorized
        case .denied:
            self = .denied
        @unknown default:
            self = .denied
        }
    }
}

// Foreground refills happen on launch and on returning to the foreground, from `RootView`.
// A phone left untouched for longer than the ten-day window is handled by
// `BackgroundRefreshScheduler` (iOS only), which books a `BGAppRefreshTaskRequest` after every
// foreground refill so the system wakes the app to refill again on its own.
