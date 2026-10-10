//
//  DailyAyahRule.swift
//  ThawabForGod
//

import Foundation

/// Which entry of the curated list is the ayah of a given day — the same for everyone on that
/// date, so the app and the widget agree without asking each other.
///
/// Ported from Mushaf as is (QURAN_MIGRATION_PLAN.md, M3; the widget arrives in M7). The days walk
/// the whole list in a fixed shuffled order before any entry comes back, so with N entries an
/// entry returns after exactly N days; the list keeps at least `minimumDaysBeforeRepeat` entries
/// (checked by `Tools/QuranBuilder` and its tests).
///
/// In `Shared/` because the widget extension runs it too. Days are Gregorian calendar days in the
/// reader's time zone, whatever calendar the region uses — `Calendar.current` is the Islamic
/// calendar in Saudi Arabia, and gave other days: the same trap `PrayerTimeEngine` documents.
nonisolated enum DailyAyahRule {
    static let minimumDaysBeforeRepeat = 60

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// Days from 2001-01-01 to the calendar day of `date`.
    static func dayNumber(for date: Date, calendar: Calendar = DailyAyahRule.calendar) -> Int {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let day = utc.date(from: components) ?? date
        let epoch = utc.date(from: DateComponents(year: 2001, month: 1, day: 1))!
        return utc.dateComponents([.day], from: epoch, to: day).day ?? 0
    }

    /// The index (0..<count) of the list entry for a calendar day.
    static func entryIndex(for date: Date, count: Int, calendar: Calendar = DailyAyahRule.calendar) -> Int {
        guard count > 0 else { return 0 }
        let position = ((dayNumber(for: date, calendar: calendar) % count) + count) % count
        return (position * stride(for: count)) % count
    }

    /// A step coprime with `count` (so every entry comes once per `count` days), about 0.38 of it:
    /// the list is in Mushaf order, and consecutive days land far apart in it.
    static func stride(for count: Int) -> Int {
        guard count > 2 else { return 1 }
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        var step = max(1, count * 382 / 1000)
        while gcd(step, count) != 1 { step += 1 }
        return step
    }

    /// `2026-10-10`: the day as a key, in the same calendar.
    static func dayKey(for date: Date, calendar: Calendar = DailyAyahRule.calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
