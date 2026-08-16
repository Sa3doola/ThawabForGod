//
//  HijriDateServiceTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct HijriDateServiceTests {

    /// Pinned to UTC so the assertions do not depend on the machine's time zone — the same
    /// reason `PrayerTimeFixtures` does it.
    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Self.gregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeService(events: [IslamicEvent] = IslamicEventTable.bundled()) -> HijriDateService {
        HijriDateService(timeZone: .gmt, events: events)
    }

    // MARK: Conversion

    /// Fixed reference points, each read off Foundation's own Umm al-Qura table before being
    /// written down here.
    @Test func itConvertsGregorianDatesToUmmAlQura() {
        let service = makeService()

        // The start of a Hijri year — the sharpest kind of boundary to be off by one on.
        #expect(service.hijriComponents(for: date(2025, 6, 26))
            == HijriDate(day: 1, month: .muharram, year: 1447))

        // Mid-month and mid-year, so no rollover can hide an off-by-one.
        #expect(service.hijriComponents(for: date(2000, 1, 1))
            == HijriDate(day: 24, month: .ramadan, year: 1420))

        // The last day of a Hijri year, which the next test steps over.
        #expect(service.hijriComponents(for: date(2026, 6, 15))
            == HijriDate(day: 29, month: .dhulHijjah, year: 1447))
    }

    /// The day after the reference above: the Hijri year has to turn over with the month.
    @Test func theHijriYearRollsOverWithItsLastDay() {
        let service = makeService()

        #expect(service.hijriComponents(for: date(2026, 6, 16))
            == HijriDate(day: 1, month: .muharram, year: 1448))
    }

    /// A Hijri day starts at local midnight in this approximation, so the same instant is two
    /// different dates either side of a zone boundary. Worth pinning: reading in UTC would put
    /// a user in Makkah a day behind for the last three hours of theirs.
    @Test func theTimeZoneDecidesWhichHijriDayAnInstantFallsOn() {
        let lateEvening = Self.gregorian.date(
            from: DateComponents(year: 2026, month: 6, day: 15, hour: 22)
        )!

        let utc = HijriDateService(timeZone: .gmt, events: [])
        let makkah = HijriDateService(timeZone: TimeZone(identifier: "Asia/Riyadh")!, events: [])

        #expect(utc.hijriComponents(for: lateEvening).day == 29)
        // 22:00 UTC is already the next day in Riyadh (UTC+3).
        #expect(makkah.hijriComponents(for: lateEvening) == HijriDate(day: 1, month: .muharram, year: 1448))
    }

    // MARK: Events

    @Test func aDateMatchingTheTableReturnsItsEvent() {
        let service = makeService()

        // 1 Muharram 1447.
        let events = service.islamicEvents(on: date(2025, 6, 26))

        #expect(events.map(\.id) == ["islamic_new_year"])
    }

    @Test func anOrdinaryDayHasNoEvents() {
        let service = makeService()

        // 29 Dhul-Hijjah 1447 — nothing is marked on it.
        #expect(service.islamicEvents(on: date(2026, 6, 15)).isEmpty)
    }

    /// Matching is on Hijri day *and* month, not day alone — otherwise the 10th of Muharram
    /// would drag Eid al-Adha along with it.
    @Test func matchingIsOnMonthAsWellAsDay() {
        let service = makeService()

        // 10 Muharram 1447 is Ashura; 10 Dhul-Hijjah 1447 is Eid al-Adha.
        #expect(service.islamicEvents(on: date(2025, 7, 5)).map(\.id) == ["ashura"])
        #expect(service.islamicEvents(on: date(2026, 5, 27)).map(\.id) == ["eid_al_adha"])
    }

    // MARK: The bundled table

    /// `IslamicEventTable.bundled()` swallows a missing or malformed resource so a packaging
    /// mistake cannot crash the app — which is exactly why the mistake has to fail here
    /// instead. This test is the only thing standing between a typo in the JSON and a Home
    /// screen that quietly never marks a single day.
    @Test func theBundledTableDecodes() {
        let events = IslamicEventTable.bundled()

        #expect(events.count == 10)
        #expect(Set(events.map(\.id)).count == events.count, "event ids must be unique")

        for event in events {
            #expect((1...30).contains(event.day), "\(event.id) has an impossible day")
        }
    }

    /// The moon-sighting caveat is not optional decoration on the dates people act on.
    @Test func theDatesThatDependOnSightingCarryANote() {
        let events = IslamicEventTable.bundled()
        let noted = Set(events.filter { $0.noteKey != nil }.map(\.id))

        #expect(noted.isSuperset(of: ["ramadan_start", "eid_al_fitr", "eid_al_adha", "arafah"]))
    }
}
