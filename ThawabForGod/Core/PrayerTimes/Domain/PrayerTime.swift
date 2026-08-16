//
//  PrayerTime.swift
//  ThawabForGod
//

import Foundation

/// One marker on the day's timeline: which prayer, and the instant it falls at.
///
/// `date` is an absolute instant, not a wall-clock time — rendering it in the user's time
/// zone and digits is the presentation layer's job.
nonisolated struct PrayerTime: Equatable, Identifiable, Sendable {
    let prayer: Prayer
    let date: Date

    var id: Prayer { prayer }

    init(prayer: Prayer, date: Date) {
        self.prayer = prayer
        self.date = date
    }
}
