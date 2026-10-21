//
//  HijriCalendarService.swift
//  ThawabForGod
//

import Foundation

/// Month grids from Foundation's Umm al-Qura calendar.
///
/// The offset moves a *label*, not a month: Hijri day *n* of the month sits on the civil day
/// Umm al-Qura puts it on, minus the offset. Month lengths are therefore the calendar's own.
nonisolated struct HijriCalendarService: HijriCalendarServicing {

    let supportedYears = 1318...1500

    private let hijri: Calendar
    private let gregorian: Calendar
    private let dayOffset: @Sendable () -> Int

    init(
        timeZone: TimeZone = .autoupdatingCurrent,
        dayOffset: @escaping @Sendable () -> Int = { 0 }
    ) {
        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.timeZone = timeZone
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        self.hijri = hijri
        self.gregorian = gregorian
        self.dayOffset = dayOffset
    }

    func monthGrid(for key: HijriMonthKey, firstWeekday: Int) -> MonthGrid? {
        guard supportedYears.contains(key.year),
              let first = hijri.date(from: DateComponents(year: key.year, month: key.month.rawValue, day: 1)),
              let length = hijri.range(of: .day, in: .month, for: first)?.count
        else { return nil }

        let offset = HijriDayOffset.clamp(dayOffset())
        let days: [MonthGrid.Day] = (0..<length).compactMap { index in
            guard let date = gregorian.date(byAdding: .day, value: index - offset, to: first) else { return nil }
            return MonthGrid.Day(number: index + 1, gregorian: gregorian.startOfDay(for: date))
        }
        guard let start = days.first else { return nil }

        let weekday = gregorian.component(.weekday, from: start.gregorian)
        let blanks = ((weekday - firstWeekday) % 7 + 7) % 7
        return MonthGrid(year: key.year, month: key.month, leadingBlanks: blanks, days: days)
    }

    func monthKey(containing date: Date) -> HijriMonthKey {
        let shifted = hijri.date(byAdding: .day, value: HijriDayOffset.clamp(dayOffset()), to: date) ?? date
        let parts = hijri.dateComponents([.year, .month], from: shifted)
        return HijriMonthKey(
            year: parts.year ?? supportedYears.lowerBound,
            month: parts.month.flatMap(HijriMonth.init(rawValue:)) ?? .muharram
        )
    }
}
