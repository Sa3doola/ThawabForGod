//
//  PrayerRecord.swift
//  ThawabForGod
//

import Foundation

/// Which of a day's obligatory prayers the user has marked as prayed.
///
/// A day at a time, not a prayer at a time. The question the tracker answers is "how did today
/// go?" and the streak is built by asking it of consecutive days — a row per prayer would make
/// both of those a grouping operation over five times as many rows, for a set that never has more
/// than five members.
///
/// **Sunrise is not in it.** It ends Fajr's window rather than starting a prayer, which is the
/// same line `Prayer.isObligatory` draws and the reminders already follow.
nonisolated struct PrayerRecord: Equatable, Sendable {
    /// Midnight of the civil day this covers, in the user's own time zone.
    let day: Date

    let completed: Set<Prayer>

    init(day: Date, completed: Set<Prayer> = []) {
        self.day = day
        // Filtered rather than trusted: a stored row from a build that tracked sunrise, or a
        // caller that passed the whole timeline, must not make "5 of 5" reachable at 4 of 5.
        self.completed = completed.filter(\.isObligatory)
    }

    /// The five that can be marked, in the order the day runs.
    static let trackable: [Prayer] = Prayer.allCases.filter(\.isObligatory)

    var completedCount: Int { completed.count }

    var isComplete: Bool { completed.count == Self.trackable.count }

    func isCompleted(_ prayer: Prayer) -> Bool { completed.contains(prayer) }

    /// The same day with one prayer marked or unmarked.
    ///
    /// A value in, a value out: the repository stores what it is given rather than being told to
    /// toggle, for the reason `QuranProgressUseCase.setBookmark` gives — a toggle has to read
    /// first to know which way to go, which makes two quick taps depend on the order their reads
    /// complete in.
    func setting(_ prayer: Prayer, to isCompleted: Bool) -> PrayerRecord {
        guard prayer.isObligatory else { return self }

        var updated = completed
        if isCompleted {
            updated.insert(prayer)
        } else {
            updated.remove(prayer)
        }

        return PrayerRecord(day: day, completed: updated)
    }
}
