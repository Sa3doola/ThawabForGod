//
//  GregorianMonthSpan.swift
//  ThawabForGod
//

import Foundation

/// The Gregorian months a Hijri month overlaps, as one line: `October – November 2026`.
///
/// A Hijri month is 29 or 30 days, so it touches two Gregorian months far more often than one.
/// Pure so the wording can be tested; the names and digits come in as closures because the app
/// keeps the digit system apart from the language.
nonisolated enum GregorianMonthSpan {

    static func text(
        first: Date,
        last: Date,
        calendar: Calendar,
        monthName: (Date) -> String,
        year: (Int) -> String
    ) -> String {
        let a = calendar.dateComponents([.year, .month], from: first)
        let b = calendar.dateComponents([.year, .month], from: last)

        if a.year == b.year && a.month == b.month {
            return "\(monthName(first)) \(year(a.year ?? 0))"
        }
        if a.year == b.year {
            return "\(monthName(first)) – \(monthName(last)) \(year(a.year ?? 0))"
        }
        return "\(monthName(first)) \(year(a.year ?? 0)) – \(monthName(last)) \(year(b.year ?? 0))"
    }
}
