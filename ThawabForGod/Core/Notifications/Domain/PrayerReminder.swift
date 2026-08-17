//
//  PrayerReminder.swift
//  ThawabForGod
//

import Foundation

/// One reminder the app intends to deliver: a prayer, and the instant it falls at.
///
/// Deliberately free of anything the notification framework understands. The window is planned
/// in these terms and translated into `UNNotificationRequest`s at the very edge, which is what
/// lets the planning — the part with the rules in it — be tested without a notification centre.
nonisolated struct PrayerReminder: Equatable, Sendable, Identifiable {
    /// Which prayer this announces. Always an obligatory one; sunrise is a marker, not a prayer.
    let prayer: Prayer

    /// When it fires.
    let date: Date

    /// Stable across refreshes, and unique per (civil day, prayer).
    ///
    /// Stability is what makes a refresh idempotent: re-adding a request under an identifier
    /// that is already pending *replaces* it rather than adding a second, so two refreshes that
    /// overlap converge on the same set instead of doubling it.
    let id: String
}

/// Builds and reads back a reminder's identifier.
///
/// Readable rather than opaque — `prayer-reminder.2026-08-17.fajr` — so a pending request can be
/// understood in a debugger or a device log without a lookup table, and so `parse` can turn the
/// pending set back into something assertable.
nonisolated enum ReminderIdentifier {
    /// Namespaced, so anything else this app ever schedules can be told apart from a reminder.
    static let prefix = "prayer-reminder"

    /// - Parameter day: the civil day the prayer belongs to — the schedule's own day, not the
    ///   components of the firing instant. At high latitudes Isha can land after midnight, and
    ///   keying on the instant would file it under the following day.
    static func make(day: DateComponents, prayer: Prayer) -> String? {
        guard let year = day.year, let month = day.month, let dayOfMonth = day.day else {
            return nil
        }

        // `String(format:)` without a locale is non-localizing, so these digits stay ASCII on a
        // device set to Arabic-Indic numerals.
        return String(format: "%@.%04d-%02d-%02d.%@", prefix, year, month, dayOfMonth, prayer.rawValue)
    }

    /// The day and prayer an identifier names, or `nil` if it is not one of ours.
    static func parse(_ identifier: String) -> (day: String, prayer: Prayer)? {
        let parts = identifier.split(separator: ".")

        guard parts.count == 3,
              parts[0] == prefix,
              let prayer = Prayer(rawValue: String(parts[2])) else {
            return nil
        }

        return (String(parts[1]), prayer)
    }
}
