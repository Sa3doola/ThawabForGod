//
//  GetPrayerScheduleUseCase.swift
//  ThawabForGod
//

import Foundation

/// Today's prayer times, and which one the app should be counting down to.
///
/// The second question is the reason this type exists. A `PrayerSchedule` can only answer it
/// within its own day, and the case that actually matters — the hours between Isha and the
/// following Fajr — needs a second day's times. That roll-over lives here, in a pure Swift
/// type with a mockable repository, so it can be tested without a clock or a view.
nonisolated struct GetPrayerScheduleUseCase: Sendable {
    private let repository: any PrayerTimeRepositoring
    private let calendar: Calendar

    /// - Parameter calendar: used only to step from one day to the next. Injected so tests
    ///   can pin a time zone rather than inherit the machine's.
    init(repository: any PrayerTimeRepositoring, calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.calendar = calendar
    }

    /// The times for the civil day `date` falls in.
    func schedule(
        for coordinates: Coordinates,
        date: Date,
        config: CalculationConfig
    ) throws -> PrayerSchedule {
        try repository.schedule(for: coordinates, date: date, config: config)
    }

    /// The next marker after `now`, rolling into the following day's Fajr once Isha has passed.
    ///
    /// The three cases worth holding in mind: before Fajr the answer is today's Fajr; between
    /// two markers it is the later of the pair; after Isha it is tomorrow's Fajr, flagged.
    func upcomingPrayer(
        for coordinates: Coordinates,
        at now: Date,
        config: CalculationConfig
    ) throws -> UpcomingPrayer {
        let today = try schedule(for: coordinates, date: now, config: config)

        if let next = today.nextPrayer(at: now) {
            return UpcomingPrayer(time: next, isTomorrow: false)
        }

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
            throw PrayerTimeError.invalidDate(now)
        }

        let tomorrowsTimes = try schedule(for: coordinates, date: tomorrow, config: config)

        guard let fajr = tomorrowsTimes.time(for: .fajr) else {
            throw PrayerTimeError.notComputable(tomorrow)
        }

        return UpcomingPrayer(time: PrayerTime(prayer: .fajr, date: fajr), isTomorrow: true)
    }
}
