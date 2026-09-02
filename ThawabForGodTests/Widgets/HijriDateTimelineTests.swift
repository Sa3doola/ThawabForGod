//
//  HijriDateTimelineTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The date widget's timeline.
///
/// Testable for the reason `NextPrayerTimelineTests` is: nothing in `HijriDateTimeline` imports
/// WidgetKit, so the app's own suite can drive it.
///
/// What is under test is the *turnover* rather than the conversion. Umm al-Qura is ICU's table and
/// `HijriDateService` is a thin read of it; what this file can get wrong is which instant the
/// widget calls a new day, and that is a question about time zones and midnights.
struct HijriDateTimelineTests {

    private let timeZone = TimeZone(identifier: "Asia/Riyadh")!

    private func makeTimeline(store: InMemorySettingsStore = InMemorySettingsStore()) -> HijriDateTimeline {
        HijriDateTimeline(
            hijriDates: HijriDateService(timeZone: timeZone, events: []),
            settingsStore: store,
            timeZone: timeZone
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func instant(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: Shape

    /// A blank rectangle on somebody's Lock Screen with no way to find out why is the failure
    /// every timeline in this project is written to avoid — and this one has no excuse for it,
    /// since a date needs neither a position nor permission.
    @Test func theTimelineIsNeverEmpty() {
        #expect(makeTimeline().entries(from: instant(2026, 6, 15, hour: 9)).isEmpty == false)
    }

    /// The first entry is `now`, not this morning's midnight: an entry dated in the past is one
    /// WidgetKit has to skip before it draws anything.
    @Test func theFirstEntryStartsNow() {
        let now = instant(2026, 6, 15, hour: 9)

        #expect(makeTimeline().entries(from: now).first?.date == now)
    }

    @Test func aFortnightOfEntriesIsHandedOver() {
        #expect(makeTimeline().entries(from: instant(2026, 6, 15, hour: 9)).count == 14)
    }

    // MARK: Turning over

    /// The one thing this type exists to get right. The civil Hijri day begins at *local*
    /// midnight, so every entry after the first has to land exactly there — an entry at UTC
    /// midnight would leave a reader in Riyadh three hours out, and one at sunset would be a
    /// different calendar altogether.
    @Test func everyEntryAfterTheFirstBeginsAtLocalMidnight() {
        let entries = makeTimeline().entries(from: instant(2026, 6, 15, hour: 9))

        for entry in entries.dropFirst() {
            let components = calendar.dateComponents([.hour, .minute, .second], from: entry.date)

            #expect(components.hour == 0)
            #expect(components.minute == 0)
            #expect(components.second == 0)
        }
    }

    @Test func theEntriesAreConsecutiveDays() {
        let entries = makeTimeline().entries(from: instant(2026, 6, 15, hour: 9))
        let days = entries.dropFirst().map { calendar.startOfDay(for: $0.date) }

        for (earlier, later) in zip(days, days.dropFirst()) {
            #expect(calendar.dateComponents([.day], from: earlier, to: later).day == 1)
        }
    }

    /// A minute before midnight the widget must still be showing today. The bug this guards is an
    /// off-by-one that would make the date roll over a day early for anyone looking at it late.
    @Test func lateAtNightTheFirstEntryIsStillToday() {
        let lateTonight = instant(2026, 6, 15, hour: 23)
        let entries = makeTimeline().entries(from: lateTonight)

        let service = HijriDateService(timeZone: timeZone, events: [])

        #expect(entries[0].hijri == service.hijriComponents(for: lateTonight))
        #expect(entries[1].date == instant(2026, 6, 16))
    }

    /// Consecutive civil days are consecutive Hijri days — the conversion is not re-derived here,
    /// only that the timeline advances it rather than repeating one date fourteen times.
    @Test func theHijriDateAdvancesWithTheEntries() {
        let entries = makeTimeline().entries(from: instant(2026, 6, 15, hour: 9))

        #expect(Set(entries.map(\.hijri.day)).count > 1)
    }

    // MARK: Coming back

    /// The horizon has to roll forward rather than run out: a reload booked inside the entries
    /// already handed over would wake the extension for nothing, and one booked at the last entry
    /// would leave the widget on its final day indefinitely.
    @Test func theReloadIsBookedAfterTheLastEntry() {
        let now = instant(2026, 6, 15, hour: 9)
        let timeline = makeTimeline()
        let entries = timeline.entries(from: now)

        let reload = timeline.reloadDate(after: entries, from: now)

        #expect(reload > entries.last!.date)
        #expect(reload == instant(2026, 6, 29))
    }

    // MARK: Style

    /// The same fallbacks the prayer widgets make, because it is the same `Style` — an unset
    /// preference means the reader has never chosen and the device decides.
    @Test func anUnsetPreferenceFallsBackRatherThanBeingWritten() {
        let entries = makeTimeline().entries(from: instant(2026, 6, 15))

        #expect(entries[0].style.accent == .fallback)
    }

    @Test func aStoredPreferenceIsRead() {
        let store = InMemorySettingsStore(strings: [.numberSystem: NumberSystem.arabicIndic.rawValue])

        #expect(makeTimeline(store: store).entries(from: instant(2026, 6, 15))[0]
            .style.numberSystem == .arabicIndic)
    }
}
