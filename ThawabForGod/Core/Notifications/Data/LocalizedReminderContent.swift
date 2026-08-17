//
//  LocalizedReminderContent.swift
//  ThawabForGod
//

import Foundation

/// Reminder text in the language the user has chosen.
///
/// Through `LocalizationManager` rather than `String(localized:)`, for the reason the whole app
/// goes through it: the language is a setting rather than the process's launch language, so
/// only the manager knows which bundle to read.
///
/// The title is the prayer's name and the body is one fixed sentence — no time, no place, no
/// count. A notification is displayed on a locked screen, so the least that carries the meaning
/// is the right amount.
@MainActor
struct LocalizedReminderContent: ReminderContentProviding {
    private let l10n: LocalizationManager

    init(l10n: LocalizationManager) {
        self.l10n = l10n
    }

    func content(for prayer: Prayer) -> ReminderContent {
        ReminderContent(
            title: l10n.string(prayer.labelKey),
            body: l10n.string(.notificationPrayerBody)
        )
    }
}
