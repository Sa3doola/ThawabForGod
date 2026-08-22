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

    /// Where this night divides, if it could be computed.
    ///
    /// Optional because it is a second calculation over the same day and the sheet that shows it
    /// is the only thing that wants it — a schedule built by hand in a test has no reason to
    /// invent one, and a day that has times but no resolvable night should still have its times.
    let night: NightTimes?

    init(day: Date, times: [PrayerTime], night: NightTimes? = nil) {
        self.day = day
        self.night = night
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
        previousPrayer(at: now)?.prayer
    }

    /// The last marker at or before `now`, or `nil` before the day's Fajr.
    ///
    /// The mirror of `nextPrayer(at:)`, and the pair is what a progress bar between two prayers
    /// is drawn from. `currentPrayer(at:)` is the same question asked without the time.
    func previousPrayer(at now: Date) -> PrayerTime? {
        times.last { $0.date <= now }
    }

    /// The first marker after `now`, or `nil` once Isha has passed.
    func nextPrayer(at now: Date) -> PrayerTime? {
        times.first { $0.date > now }
    }
}
