//
//  HijriCalendarServicing.swift
//  ThawabForGod
//

import Foundation

/// Lays out Hijri months. Separate from `HijriDateServicing` so the widget and Home, which only
/// ask "what day is it", do not take on a month-grid requirement.
nonisolated protocol HijriCalendarServicing: Sendable {
    /// The years Umm al-Qura is trusted for; navigation stops at the ends.
    var supportedYears: ClosedRange<Int> { get }

    /// `nil` outside `supportedYears`.
    /// - Parameter firstWeekday: `Calendar` numbering, 1 = Sunday.
    func monthGrid(for key: HijriMonthKey, firstWeekday: Int) -> MonthGrid?

    /// The month the given instant is in, after the reader's offset.
    func monthKey(containing date: Date) -> HijriMonthKey
}
