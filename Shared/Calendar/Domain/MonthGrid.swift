//
//  MonthGrid.swift
//  ThawabForGod
//

import Foundation

/// One Hijri month laid out for a seven-column week grid.
///
/// Numbers and dates only, never text — the same rule `HijriDate` follows.
nonisolated struct MonthGrid: Equatable, Sendable {

    nonisolated struct Day: Equatable, Sendable, Identifiable {
        /// 1-based day of the Hijri month, *after* the reader's offset.
        let number: Int
        /// The civil day it falls on, at the start of that day in the calendar's time zone.
        let gregorian: Date

        var id: Int { number }
    }

    let year: Int
    let month: HijriMonth
    /// Empty cells before day 1 in the first week row.
    let leadingBlanks: Int
    /// 29 or 30 entries, read from the calendar and never assumed.
    let days: [Day]

    /// Cells in row-major order, `nil` for the blanks; its count is a whole number of weeks
    /// only if trailing blanks are wanted, which a `LazyVGrid` does not need.
    var cells: [Day?] {
        Array(repeating: nil, count: leadingBlanks) + days.map(Optional.some)
    }

    var key: HijriMonthKey { HijriMonthKey(year: year, month: month) }
}

/// A month in a year — the address of a page in the calendar pager.
nonisolated struct HijriMonthKey: Hashable, Comparable, Sendable {
    let year: Int
    let month: HijriMonth

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month.rawValue) < (rhs.year, rhs.month.rawValue)
    }

    var next: Self {
        month == .dhulHijjah
            ? Self(year: year + 1, month: .muharram)
            : Self(year: year, month: HijriMonth(rawValue: month.rawValue + 1)!)
    }

    var previous: Self {
        month == .muharram
            ? Self(year: year - 1, month: .dhulHijjah)
            : Self(year: year, month: HijriMonth(rawValue: month.rawValue - 1)!)
    }
}

/// Which weekday a calendar row starts on. `.locale` defers to the device.
nonisolated enum WeekStart: String, CaseIterable, Sendable {
    case locale, saturday, sunday, monday

    /// `Calendar`'s numbering: 1 is Sunday.
    func firstWeekday(locale: Locale = .autoupdatingCurrent) -> Int {
        switch self {
        case .locale: Calendar(identifier: .gregorian).firstWeekday(in: locale)
        case .saturday: 7
        case .sunday: 1
        case .monday: 2
        }
    }
}

private nonisolated extension Calendar {
    func firstWeekday(in locale: Locale) -> Int {
        var calendar = self
        calendar.locale = locale
        return calendar.firstWeekday
    }
}
