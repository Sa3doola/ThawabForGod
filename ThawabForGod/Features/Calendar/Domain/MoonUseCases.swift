//
//  MoonUseCases.swift
//  ThawabForGod
//

import Foundation

/// The moon as it stands on a civil day, read at that day's Maghrib.
///
/// Maghrib because it is the hour the Hijri day is read from — the crescent, if there is one, is
/// looked for after sunset — and so the one moment a calendar cell's moon is worth quoting. Where
/// the prayer times cannot be computed (no usable coordinates, or the sun never sets there) the
/// answer is 18:00 local rather than none: the phase changes by under a percent an hour, so the
/// fallback cannot be told apart on a screen.
nonisolated struct GetMoonInfoUseCase: Sendable {
    private let moon: any MoonPhaseCalculating
    private let schedule: GetPrayerScheduleUseCase
    private let calendar: Calendar

    init(
        moon: any MoonPhaseCalculating,
        schedule: GetPrayerScheduleUseCase,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.moon = moon
        self.schedule = schedule
        self.calendar = calendar
    }

    /// When the moon is read for `day`.
    func evaluationTime(on day: Date, coordinates: Coordinates, config: CalculationConfig) -> Date {
        if let maghrib = try? schedule.schedule(for: coordinates, date: day, config: config).time(for: .maghrib) {
            return maghrib
        }
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .hour, value: 18, to: start) ?? start
    }

    func callAsFunction(on day: Date, coordinates: Coordinates, config: CalculationConfig) -> MoonInfo {
        moon.info(at: evaluationTime(on: day, coordinates: coordinates, config: config))
    }
}

/// The eight phases of the lunation that `date` falls in, for the strip on the moon screen.
///
/// Each entry is the moon at an even eighth of the way from the last new moon to the next, so the
/// strip shows a cycle the reader is inside rather than eight timeless pictures. The instants are
/// an even division of an uneven month — within a day or so of when each phase is exact, which is
/// what an illustration needs and not something to quote as a time.
nonisolated struct GetMoonPhaseStripUseCase: Sendable {
    private let moon: any MoonPhaseCalculating

    init(moon: any MoonPhaseCalculating) {
        self.moon = moon
    }

    func callAsFunction(around date: Date) -> [MoonInfo] {
        let start = moon.lastNewMoon(onOrBefore: date)
        let end = moon.nextNewMoon(after: date)
        let span = end.timeIntervalSince(start)
        return (0..<8).map { step in
            moon.info(at: start.addingTimeInterval(span * Double(step) / 8))
        }
    }
}

/// The next new moon and the next full moon after an instant.
nonisolated struct GetNextMoonEventsUseCase: Sendable {

    nonisolated struct Events: Equatable, Sendable {
        let newMoon: Date
        let fullMoon: Date
    }

    private let moon: any MoonPhaseCalculating

    init(moon: any MoonPhaseCalculating) {
        self.moon = moon
    }

    func callAsFunction(after date: Date) -> Events {
        Events(newMoon: moon.nextNewMoon(after: date), fullMoon: moon.nextFullMoon(after: date))
    }
}
