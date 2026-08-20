//
//  RemindersSettingsViewModel.swift
//  ThawabForGod
//

import Observation

/// Which prayers get a reminder, and whether the system will deliver one at all.
///
/// Turning a prayer off is a preference rather than a cancellation: the toggle is written to the
/// store, and the next refresh — which the composition root triggers when this set changes —
/// rebuilds the pending window without it. Nothing here talks to the notification centre.
@Observable
@MainActor
final class RemindersSettingsViewModel {

    /// Whether the system will actually deliver reminders, or `nil` until it has been asked.
    ///
    /// Worth having: without it the toggles would look live while iOS silently dropped every
    /// notification, which is the sort of thing a user blames the app for.
    private(set) var notificationsAllowed: Bool?

    @ObservationIgnored private let reminders: ReminderPreferences
    @ObservationIgnored private let notifications: any NotificationService

    init(reminders: ReminderPreferences, notifications: any NotificationService) {
        self.reminders = reminders
        self.notifications = notifications
    }

    /// The five prayers a reminder can be set for. Sunrise is not among them — it ends Fajr's
    /// window rather than starting a prayer.
    var remindablePrayers: [Prayer] { Prayer.remindable }

    func isEnabled(_ prayer: Prayer) -> Bool {
        reminders.isEnabled(prayer)
    }

    func setEnabled(_ isEnabled: Bool, for prayer: Prayer) {
        reminders.setEnabled(isEnabled, for: prayer)
    }

    /// Asks the system whether reminders can be delivered at all.
    ///
    /// Driven from the screen's `.task`, so it re-runs on each appearance — permission can be
    /// revoked in the Settings app while this app sits in the background, and the answer read at
    /// construction would be stale by the time anybody looked at it.
    func loadNotificationStatus() async {
        notificationsAllowed = await notifications.authorizationStatus() == .authorized
    }
}
