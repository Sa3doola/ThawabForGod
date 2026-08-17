//
//  Prayer+Reminders.swift
//  ThawabForGod
//

import Foundation

nonisolated extension Prayer {
    /// The key holding whether this prayer's reminder is on, or `nil` for sunrise.
    ///
    /// Sunrise having no key is the type system carrying the rule: it marks the end of Fajr's
    /// window rather than the start of a prayer, so there is nothing to remind anyone to do, and
    /// no toggle to draw for it.
    var reminderSettingsKey: SettingsKey? {
        switch self {
        case .fajr: .reminderFajr
        case .sunrise: nil
        case .dhuhr: .reminderDhuhr
        case .asr: .reminderAsr
        case .maghrib: .reminderMaghrib
        case .isha: .reminderIsha
        }
    }

    /// The five a reminder can be set for, in the order they fall.
    static let remindable = allCases.filter(\.isObligatory)
}

nonisolated extension SettingsStore {
    /// The prayers whose reminders are switched on.
    ///
    /// One decode, two readers: `ReminderPreferences` holds the observable copy for Settings to
    /// edit, and `AppReminderInputs` re-reads it at refresh time. The defaulting rule — unset
    /// means on — has to be identical in both, so it lives here rather than in each.
    var enabledReminderPrayers: Set<Prayer> {
        Set(
            Prayer.remindable.filter { prayer in
                guard let key = prayer.reminderSettingsKey else { return false }
                return bool(for: key) ?? true
            }
        )
    }
}
