//
//  QuranWidgetTimeline.swift
//  ThawabForGod
//

import Foundation

/// One moment of a Quran widget: the stored snapshot (nil until the app has written one), the
/// presentation choices, and whether the Hafs face is registered in this process. The extension
/// adds `TimelineEntry` to it; this file stays free of WidgetKit so the tests can reach it.
nonisolated struct QuranWidgetEntry: Sendable {
    let date: Date
    let snapshot: QuranWidgetSnapshot?
    let style: NextPrayerSnapshot.Style
    let hasHafs: Bool
}

nonisolated enum QuranWidgetFamily: Sendable, CaseIterable {
    case small, medium, large, rectangular
}

/// Pure timeline construction for the two Quran kinds.
///
/// The Ayah of the Day hands over a week of entries, one per midnight, so the ayah turns over even
/// if WidgetKit skips a reload; each entry's ayah is chosen by the view from `entry.date`.
nonisolated enum QuranWidgetTimeline {
    static let daysAhead = 7

    static func nextMidnight(after now: Date, calendar: Calendar = DailyAyahRule.calendar) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(24 * 60 * 60)
    }

    static func ayahOfTheDay(
        now: Date, snapshot: QuranWidgetSnapshot?, style: NextPrayerSnapshot.Style, hasHafs: Bool,
        calendar: Calendar = DailyAyahRule.calendar
    ) -> (entries: [QuranWidgetEntry], reloadAfter: Date) {
        func entry(_ date: Date) -> QuranWidgetEntry {
            QuranWidgetEntry(date: date, snapshot: snapshot, style: style, hasHafs: hasHafs)
        }
        var entries = [entry(now)]
        var last = now
        // With no snapshot there is nothing to turn over, only the wait for the app to publish one.
        guard snapshot != nil else { return (entries, nextMidnight(after: now, calendar: calendar)) }
        for _ in 0..<daysAhead {
            last = nextMidnight(after: last, calendar: calendar)
            entries.append(entry(last))
        }
        return (entries, last)
    }

    static func continueReading(
        now: Date, snapshot: QuranWidgetSnapshot?, style: NextPrayerSnapshot.Style, hasHafs: Bool,
        calendar: Calendar = DailyAyahRule.calendar
    ) -> (entries: [QuranWidgetEntry], reloadAfter: Date) {
        ([QuranWidgetEntry(date: now, snapshot: snapshot, style: style, hasHafs: hasHafs)],
         nextMidnight(after: now, calendar: calendar))
    }
}
