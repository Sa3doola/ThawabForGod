//
//  ReminderCategory+Registration.swift
//  ThawabForGod
//

import UserNotifications

/// The app's reminder kinds, as `UNUserNotificationCenter` wants them.
///
/// A Data-layer extension because it names a UserNotifications type, and `ReminderCategory` itself
/// lives in `Shared/` where the content extension can read it. The enum is the contract; this is
/// the one translation of it.
///
/// **No actions.** A category exists here to give the content extension something to register
/// against, not to put buttons on a banner — "log this prayer" from the Lock Screen is a slice of
/// its own, with a decision in it about whether an unread notification may record something the
/// reader has not done.
///
/// `hiddenPreviewsBodyPlaceholder` is deliberately left alone: a prayer reminder carries nothing
/// private, and replacing its body with "Notification" on a locked screen would hide the one line
/// the reader needs while the phone is face up on a table.
nonisolated extension ReminderCategory {

    static var registrations: Set<UNNotificationCategory> {
        Set(allCases.map(\.registration))
    }

    var registration: UNNotificationCategory {
        UNNotificationCategory(
            identifier: identifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
    }
}
