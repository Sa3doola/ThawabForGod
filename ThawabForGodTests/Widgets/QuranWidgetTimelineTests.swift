//
//  QuranWidgetTimelineTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The day rule and the timelines the two Quran widgets are drawn from (M8-B4, section 7).
///
/// None of it imports WidgetKit, so the suite runs in the app's test target. Every date is built in
/// an explicit calendar: the rule is about the reader's day, and `Calendar.current` is the Islamic
/// calendar on a device set to it.
struct QuranWidgetTimelineTests {

    private static let style = NextPrayerSnapshot.Style(
        numberSystem: .latin, clockFormat: .fallback, accent: .fallback, language: .english
    )

    // MARK: Helpers

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// A snapshot with an entry for each index in `indices`, out of a list of `count`.
    private func snapshot(indices: [Int], count: Int) -> QuranWidgetSnapshot {
        QuranWidgetSnapshot(
            entries: indices.map { index in
                QuranWidgetSnapshot.DailyAyah(
                    index: index,
                    first: VerseReference(surah: 2, verse: index % 286 + 1),
                    lastVerse: index % 286 + 1,
                    surahNameArabic: "البقرة",
                    surahNameEnglish: "Al-Baqarah",
                    texts: ["text \(index)"],
                    translation: nil
                )
            },
            listCount: count
        )
    }

    private func fullSnapshot(count: Int) -> QuranWidgetSnapshot {
        snapshot(indices: Array(0..<count), count: count)
    }

    private func entryIndex(_ date: Date, count: Int, _ calendar: Calendar) -> Int {
        DailyAyahRule.entryIndex(for: date, count: count, calendar: calendar)
    }

    // MARK: Ayah of the day: the shape of the timeline

    /// The entry now, then one at each of the next `daysAhead` midnights, and the reload after the last.
    @Test func ayahEntriesAreNowThenEachLocalMidnight() {
        let london = calendar("Europe/London")
        let now = date(2026, 6, 15, 14, 30, in: london)
        let result = QuranWidgetTimeline.ayahOfTheDay(
            now: now, snapshot: fullSnapshot(count: 125), style: Self.style, hasHafs: true, calendar: london
        )

        #expect(QuranWidgetTimeline.daysAhead == 7)
        #expect(result.entries.count == 1 + QuranWidgetTimeline.daysAhead)
        let dates = result.entries.map(\.date)
        #expect(dates.first == now)
        #expect(dates.dropFirst().allSatisfy { london.startOfDay(for: $0) == $0 }, "each after the first is a local midnight")
        #expect(zip(dates, dates.dropFirst()).allSatisfy { pair in pair.0 < pair.1 }, "strictly increasing")
        #expect(dates[1] == date(2026, 6, 16, 0, 0, in: london))
        #expect(result.reloadAfter == dates.last)
    }

    /// Each entry, asked which ayah it is, gets the entry the day rule names for its own date.
    @Test func eachEntryAnswersWithTheDayRuleForItsOwnDate() {
        let riyadh = calendar("Asia/Riyadh")
        let now = date(2026, 10, 8, 10, 0, in: riyadh)
        let result = QuranWidgetTimeline.ayahOfTheDay(
            now: now, snapshot: fullSnapshot(count: 125), style: Self.style, hasHafs: true, calendar: riyadh
        )

        for entry in result.entries {
            let shown = entry.snapshot?.dailyAyah(for: entry.date, calendar: riyadh)
            #expect(shown?.index == entryIndex(entry.date, count: 125, riyadh), "\(entry.date)")
        }
    }

    /// Every midnight in the timeline is a new day, so the days shown run on without a gap or repeat.
    @Test func timelineDaysAreConsecutive() {
        let riyadh = calendar("Asia/Riyadh")
        let result = QuranWidgetTimeline.ayahOfTheDay(
            now: date(2026, 10, 8, 10, 0, in: riyadh), snapshot: fullSnapshot(count: 125),
            style: Self.style, hasHafs: true, calendar: riyadh
        )
        let keys = result.entries.map { DailyAyahRule.dayKey(for: $0.date, calendar: riyadh) }
        #expect(keys == ["2026-10-08", "2026-10-09", "2026-10-10", "2026-10-11", "2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15"])
    }

    /// Without a snapshot there is nothing to show but the wait: one entry, and a reload after it.
    @Test func withoutASnapshotThereIsOneEntry() {
        let london = calendar("Europe/London")
        let now = date(2026, 6, 15, 14, 30, in: london)
        let result = QuranWidgetTimeline.ayahOfTheDay(
            now: now, snapshot: nil, style: Self.style, hasHafs: true, calendar: london
        )
        #expect(result.entries.count == 1)
        #expect(result.entries.first?.snapshot == nil)
        #expect(result.reloadAfter > now)
    }

    // MARK: The day rule across time zones

    /// The reader's midnight, not UTC's: 23:59 and 00:01 in Riyadh are two days, and they are two
    /// different ayahs.
    @Test func riyadhMidnightIsTheDayBoundary() {
        let riyadh = calendar("Asia/Riyadh")
        let late = date(2026, 10, 8, 23, 59, in: riyadh)
        let early = date(2026, 10, 9, 0, 1, in: riyadh)

        #expect(DailyAyahRule.dayKey(for: late, calendar: riyadh) == "2026-10-08")
        #expect(DailyAyahRule.dayKey(for: early, calendar: riyadh) == "2026-10-09")
        #expect(entryIndex(late, count: 125, riyadh) != entryIndex(early, count: 125, riyadh))

        let snapshot = fullSnapshot(count: 125)
        #expect(snapshot.dailyAyah(for: late, calendar: riyadh)?.index != snapshot.dailyAyah(for: early, calendar: riyadh)?.index)

        let result = QuranWidgetTimeline.ayahOfTheDay(
            now: late, snapshot: snapshot, style: Self.style, hasHafs: true, calendar: riyadh
        )
        #expect(result.entries[1].date == date(2026, 10, 9, 0, 0, in: riyadh))
    }

    /// One instant is two days at once: 01:00 on the 8th in Riyadh is still the 7th in UTC, and the
    /// two calendars name different ayahs for it.
    @Test func utcAndRiyadhDisagreeAboutTheSameInstant() {
        let riyadh = calendar("Asia/Riyadh")
        let utc = calendar("UTC")
        let instant = date(2026, 10, 8, 1, 0, in: riyadh)

        #expect(DailyAyahRule.dayKey(for: instant, calendar: riyadh) == "2026-10-08")
        #expect(DailyAyahRule.dayKey(for: instant, calendar: utc) == "2026-10-07")
        #expect(entryIndex(instant, count: 125, riyadh) != entryIndex(instant, count: 125, utc))
    }

    /// London's clocks go back on 25 October 2026, and that day is 25 hours long. The timeline must
    /// still name every day once: no day skipped, none repeated.
    @Test func londonClocksGoingBackNeitherSkipsNorRepeatsADay() {
        let london = calendar("Europe/London")
        let now = date(2026, 10, 24, 12, 0, in: london)
        let result = QuranWidgetTimeline.ayahOfTheDay(
            now: now, snapshot: fullSnapshot(count: 125), style: Self.style, hasHafs: true, calendar: london
        )

        let keys = result.entries.map { DailyAyahRule.dayKey(for: $0.date, calendar: london) }
        #expect(keys == [
            "2026-10-24", "2026-10-25", "2026-10-26", "2026-10-27",
            "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31",
        ])
        let dates = result.entries.map(\.date)
        // 25 October is the 25-hour day: from its midnight to 26 October's is 25 hours. Every day after
        // the change is 24, and a timeline that counted the change as a day twice would show 23 or 26.
        #expect(dates[2].timeIntervalSince(dates[1]) == 25 * 60 * 60)
        for index in 2..<(dates.count - 1) {
            #expect(dates[index + 1].timeIntervalSince(dates[index]) == 24 * 60 * 60, "entry \(index)")
        }
    }

    // MARK: Snapshot lookups

    /// A day whose entry was left out of the snapshot answers nothing, not the entry before it.
    @Test func aDayWithNoEntryInTheSnapshotIsNil() throws {
        let utc = calendar("UTC")
        let start = date(2026, 1, 1, 12, 0, in: utc)
        // Indices 0, 1, 2 are published; the list has 5, and the day lands on the missing 3.
        let partial = snapshot(indices: [0, 1, 2], count: 5)

        let missing = try #require(
            (0..<40)
                .compactMap { utc.date(byAdding: .day, value: $0, to: start) }
                .first { entryIndex($0, count: 5, utc) == 3 }
        )
        #expect(partial.dailyAyah(for: missing, calendar: utc) == nil)
    }

    /// The snapshot written by a build before the list was published whole (`days`, keyed by date)
    /// does not decode, so the widget shows nothing until the app rebuilds it.
    @Test func theOldDaysShapeDoesNotLoad() {
        let old = #"{"days":[{"day":"2026-10-08","first":{"surah":1,"verse":1},"lastVerse":7,"surahNameArabic":"الفاتحة","surahNameEnglish":"Al-Fatihah","texts":["x"]}],"listID":"abc"}"#
        let store = InMemorySettingsStore(strings: [.quranWidgetSnapshot: old])
        #expect(QuranWidgetSnapshot.load(from: store) == nil)
    }

    @Test func aSnapshotRoundTripsThroughTheStore() {
        let store = InMemorySettingsStore()
        var snapshot = fullSnapshot(count: 3)
        snapshot.listID = "abc"
        snapshot.fontVersion = "1.0"
        snapshot.save(to: store)
        #expect(QuranWidgetSnapshot.load(from: store) == snapshot)
    }

    // MARK: Continue Reading

    /// One entry, and the reload at the next midnight: nothing on it moves between midnights.
    @Test func continueReadingIsOneEntryUntilMidnight() {
        let london = calendar("Europe/London")
        let now = date(2026, 6, 15, 14, 30, in: london)
        let result = QuranWidgetTimeline.continueReading(
            now: now, snapshot: nil, style: Self.style, hasHafs: true, calendar: london
        )
        #expect(result.entries.count == 1)
        #expect(result.entries.first?.date == now)
        #expect(result.reloadAfter == date(2026, 6, 16, 0, 0, in: london))
    }

    // MARK: Midnight

    @Test func nextMidnightIsTheStartOfTomorrowAndIsStrictlyLater() {
        let riyadh = calendar("Asia/Riyadh")
        let late = date(2026, 10, 8, 23, 59, in: riyadh)
        #expect(QuranWidgetTimeline.nextMidnight(after: late, calendar: riyadh) == date(2026, 10, 9, 0, 0, in: riyadh))

        let midnight = date(2026, 10, 9, 0, 0, in: riyadh)
        #expect(QuranWidgetTimeline.nextMidnight(after: midnight, calendar: riyadh) == date(2026, 10, 10, 0, 0, in: riyadh))
    }

    // MARK: A preview is instant and small (B16)

    @Test func theTimelineHoldsOnlyAWeekOfTheList() {
        let calendar = calendar("Asia/Riyadh")
        let now = date(2026, 10, 21, 9, in: calendar)
        let result = QuranWidgetTimeline.ayahOfTheDay(
            now: now, snapshot: fullSnapshot(count: 200), style: Self.style, hasHafs: true, calendar: calendar)
        for entry in result.entries {
            #expect((entry.snapshot?.entries.count ?? 0) <= QuranWidgetTimeline.daysAhead + 3)
            // Trimming never costs an entry its own day.
            #expect(entry.snapshot?.dailyAyah(for: entry.date, calendar: calendar) != nil)
        }
    }

    @Test func continueReadingCarriesNoDailyList() {
        var full = fullSnapshot(count: 200)
        full.continueReading = .init(ayah: VerseReference(surah: 2, verse: 1), surahNameArabic: "البقرة",
                                     surahNameEnglish: "Al-Baqarah", page: nil, juz: 1)
        let result = QuranWidgetTimeline.continueReading(
            now: Date(), snapshot: full, style: Self.style, hasHafs: true)
        #expect(result.entries.first?.snapshot?.entries.isEmpty == true)
        #expect(result.entries.first?.snapshot?.continueReading != nil)
    }

    @Test func theBundledSampleDrawsADayAndNeedsNoFont() async throws {
        let sample = try #require(QuranWidgetSnapshot.sample())
        let entry = QuranWidgetTimeline.previewEntry(now: Date(), sample: sample, style: .preview())
        #expect(entry.hasHafs == false)
        let day = try #require(entry.snapshot?.dailyAyah(for: Date()))
        #expect(day.first == VerseReference(surah: 94, verse: 5))
        #expect(day.texts.count == 2)
        // The Quran text is only ever copied: the sample's words are the stored ones, character for character.
        let stored = try await QuranTestData.repository(QuranTestData.publicDatabase).loadCorpus(style: .madaniV2)
        #expect(day.texts == [stored.ayah(VerseReference(surah: 94, verse: 5))?.text, stored.ayah(VerseReference(surah: 94, verse: 6))?.text].compactMap { $0 })
        #expect(entry.snapshot?.continueReading != nil)
    }

    /// The numbers behind the fix, for a list of the size B4 publishes (about 250 entries with a
    /// translation). Simulator, not a device: it shows the order of magnitude, not the extension's
    /// real footprint. Printed so a run records them; the bounds are generous on purpose.
    @Test func decodingAndTrimmingTheWholeListIsCheap() throws {
        // Filler of the same byte weight as a long ayah with a translation, so no verse text is typed here.
        let long = String(repeating: "\u{0648}\u{064E}\u{0671}\u{0644}\u{0652} ", count: 90)
        var full = QuranWidgetSnapshot(entries: (0..<250).map { index in
            QuranWidgetSnapshot.DailyAyah(
                index: index, first: VerseReference(surah: 2, verse: index % 286 + 1), lastVerse: index % 286 + 1,
                surahNameArabic: "البقرة", surahNameEnglish: "Al-Baqarah", texts: [long],
                translation: .init(packID: "x", nameArabic: "x", nameEnglish: "x", texts: [long], isRightToLeft: false))
        }, listCount: 250)
        full.listID = "x"
        let data = try JSONEncoder().encode(full)

        let clock = ContinuousClock()
        var decoded: QuranWidgetSnapshot?
        let decodeTime = clock.measure { decoded = try? JSONDecoder().decode(QuranWidgetSnapshot.self, from: data) }
        let before = Self.footprint()
        let trimmed = try #require(decoded).trimmed(from: Date(), days: 8)
        let trimmedData = try JSONEncoder().encode(trimmed)
        #expect(decodeTime < .milliseconds(500))
        #expect(trimmedData.count * 10 < data.count)
    }

    private static func footprint() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
    }
}
