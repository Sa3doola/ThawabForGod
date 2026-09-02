//
//  LocalizedReminderContent.swift
//  ThawabForGod
//

import Foundation

/// Reminder text in the language the user has chosen.
///
/// Through `LocalizationManager` rather than `String(localized:)`, for the reason the whole app
/// goes through it: the language is a setting rather than the process's launch language, so
/// only the manager knows which bundle to read. The time goes through it too — `timeString(_:)`,
/// the same call every screen in the app makes — so the digits and the hour cycle on a banner are
/// the ones the reader chose.
///
/// Three lines, and no more: the prayer's name, its time, and one fixed sentence. A notification
/// is displayed on a locked screen, so the least that carries the meaning is the right amount.
@MainActor
struct LocalizedReminderContent: ReminderContentProviding {
    private let l10n: LocalizationManager

    init(l10n: LocalizationManager) {
        self.l10n = l10n
    }

    func content(for reminder: PrayerReminder) -> ReminderContent {
        let body = l10n.string(.notificationPrayerBody)

        return ReminderContent(
            title: l10n.string(reminder.prayer.labelKey),
            subtitle: l10n.timeString(reminder.date),
            body: body,
            presentation: ReminderPresentation(
                subject: .prayer(reminder.prayer),
                date: reminder.date,
                body: body
            )
        )
    }
}
