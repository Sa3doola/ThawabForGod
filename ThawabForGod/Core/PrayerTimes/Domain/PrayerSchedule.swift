//
//  PrayerSchedule.swift
//  ThawabForGod
//

import Foundation

/// One civil day's prayer times, plus the two questions every screen asks of them: which
/// prayer are we in, and which one is next.
///
/// Both answers are deliberately scoped to *this day*. Once Isha has passed there is no next
/// prayer here — resolving that roll-over needs tomorrow's times, which is
/// `GetPrayerScheduleUseCase`'s job, not this value's.
nonisolated struct PrayerSchedule: Equatable, Sendable {
    /// Midnight of the day these times belong to, in the time zone they were computed for.
    let day: Date

    /// The day's markers in chronological order.
    let times: [PrayerTime]

    init(day: Date, times: [PrayerTime]) {
        self.day = day
        // Sorting rather than trusting the caller: the order is load-bearing for both
        // lookups below, and a schedule built by hand in a test is easy to get wrong.
        self.times = times.sorted { $0.date < $1.date }
    }

    func time(for prayer: Prayer) -> Date? {
        times.first { $0.prayer == prayer }?.date
    }

    /// The marker whose window `now` falls in, or `nil` before the day's Fajr — at that hour
    /// the current prayer is yesterday's Isha, which this day's times cannot speak to.
    func currentPrayer(at now: Date) -> Prayer? {
        times.last { $0.date <= now }?.prayer
    }

    /// The first marker after `now`, or `nil` once Isha has passed.
    func nextPrayer(at now: Date) -> PrayerTime? {
        times.first { $0.date > now }
    }
}
