//
//  PassedPrayer.swift
//  ThawabForGod
//

import Foundation

/// The marker the current window opened at — the mirror image of `UpcomingPrayer`.
///
/// It carries `isYesterday` for the same reason its twin carries `isTomorrow`: the interesting
/// case is the hours before Fajr, where the answer is Isha but it is the *previous* day's Isha,
/// and a progress bar drawn from today's would run backwards.
nonisolated struct PassedPrayer: Equatable, Sendable {
    let time: PrayerTime

    /// True before the day's Fajr, when the last marker to pass belonged to the day before.
    let isYesterday: Bool

    var prayer: Prayer { time.prayer }
    var date: Date { time.date }

    init(time: PrayerTime, isYesterday: Bool) {
        self.time = time
        self.isYesterday = isYesterday
    }
}
