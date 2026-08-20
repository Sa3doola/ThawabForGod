//
//  PrayerTrackerRepositoring.swift
//  ThawabForGod
//

import Foundation

/// Which prayers were prayed, by day.
nonisolated protocol PrayerTrackerRepositoring: Sendable {
    /// The row for a day, or an empty one — a day nobody has marked anything on is not a missing
    /// day, it is a day with nothing marked, and callers should not have to tell those apart.
    func record(on day: Date) async throws -> PrayerRecord

    /// The rows from `start` to `end` inclusive, most recent first, skipping days with nothing on
    /// them. What the streak is counted from.
    func records(from start: Date, to end: Date) async throws -> [PrayerRecord]

    /// Stores a day's state. Writes the row if there is none, and deletes it when nothing is left
    /// marked — an empty row is indistinguishable from no row, and keeping it would grow the
    /// store by a row per day the user opened the sheet and changed their mind.
    func save(_ record: PrayerRecord) async throws
}
