//
//  UpcomingPrayer.swift
//  ThawabForGod
//

import Foundation

/// The prayer a countdown is running towards.
///
/// It carries `isTomorrow` because the interesting case is the one after Isha: the answer is
/// still "Fajr", but it is a different day's Fajr, and the screen should say so.
nonisolated struct UpcomingPrayer: Equatable, Sendable {
    let time: PrayerTime

    /// True once Isha has passed and the countdown has rolled over to the next day's Fajr.
    let isTomorrow: Bool

    var prayer: Prayer { time.prayer }
    var date: Date { time.date }

    init(time: PrayerTime, isTomorrow: Bool) {
        self.time = time
        self.isTomorrow = isTomorrow
    }
}
