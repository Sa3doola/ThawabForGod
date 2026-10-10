//
//  DailyAyahRuleTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Which entry of the curated list is a day's ayah: every entry once before any comes back, and the
/// day counted in Gregorian days whatever calendar the region uses. Ported from Mushaf's
/// `WidgetTests` with the rule (M3); the rest of that suite — the published snapshot, the links,
/// the curated list — arrives with the widgets in M7.
struct DailyAyahRuleTests {

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Whatever the list's length, every entry comes once before any comes back.
    @Test func dayIndexWalksTheWholeListBeforeRepeating() {
        let calendar = utc
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        for count in [1, 2, 3, 60, 61, 100, 120, 125, 128, 144, 240] {
            var lastSeen: [Int: Int] = [:]
            var shortest = Int.max
            for day in 0..<(count * 3) {
                let index = DailyAyahRule.entryIndex(for: calendar.date(byAdding: .day, value: day, to: start)!, count: count, calendar: calendar)
                #expect((0..<count).contains(index))
                if let previous = lastSeen[index] { shortest = min(shortest, day - previous) }
                lastSeen[index] = day
            }
            #expect(lastSeen.count == count, "every entry is used (\(count))")
            if count > 1 { #expect(shortest == count, "an entry returns after \(count) days, not \(shortest)") }
        }
        // Morning and evening of one day give the same entry; the next day another.
        let at = { (hours: Int) in DailyAyahRule.entryIndex(for: calendar.date(byAdding: .hour, value: hours, to: start)!, count: 125, calendar: calendar) }
        #expect(at(1) == at(23) && at(1) != at(25))
    }

    /// In Saudi Arabia `Calendar.current` is Islamic; the rule still counts Gregorian days.
    @Test func dayKeysAreGregorianEverywhere() {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Riyadh")
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let day = formatter.date(from: "2026-10-08T10:00:00")!
        var islamic = Calendar(identifier: .islamicUmmAlQura)
        islamic.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        var rule = DailyAyahRule.calendar
        rule.timeZone = TimeZone(identifier: "Asia/Riyadh")!

        #expect(DailyAyahRule.dayKey(for: day, calendar: rule) == "2026-10-08")
        #expect(DailyAyahRule.calendar.identifier == .gregorian)
        #expect(islamic.component(.year, from: day) != 2026, "the calendar the region uses differs")
    }
}
