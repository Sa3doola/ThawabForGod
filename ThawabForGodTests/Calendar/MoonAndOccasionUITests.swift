//
//  MoonAndOccasionUITests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct MoonAndOccasionUITests {

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Self.gregorian.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func makeModels() -> (HijriCalendarViewModel, MoonDetailViewModel) {
        let months = HijriCalendarService(timeZone: .gmt)
        let moon = AstronomicalMoonCalculator()
        let clock = TestClock(date(2025, 7, 2).addingTimeInterval(12 * 3600))
        let calendar = HijriCalendarViewModel(
            calendar: months,
            occasions: ResolveOccasionDatesUseCase(repository: BundledOccasionsRepository(), calendar: months),
            moon: GetMoonInfoUseCase(
                moon: moon,
                schedule: GetPrayerScheduleUseCase(repository: PrayerTimeRepository(engine: PrayerTimeEngine()))
            ),
            hijriDates: HijriDateService(timeZone: .gmt),
            settingsStore: InMemorySettingsStore(),
            coordinates: { .makkah },
            config: { .default },
            clock: clock,
            timeZone: .gmt,
            locale: Locale(identifier: "en_US")
        )
        let detail = MoonDetailViewModel(
            calendar: calendar,
            strip: GetMoonPhaseStripUseCase(moon: moon),
            next: GetNextMoonEventsUseCase(moon: moon),
            clock: clock
        )
        return (calendar, detail)
    }

    // MARK: Wording

    @Test func arabicCountsTakeTheirOwnNounForm() {
        #expect(DayCountPhrase.key(for: 1, isArabic: true) == .dayCountOne)
        #expect(DayCountPhrase.key(for: 2, isArabic: true) == .dayCountTwo)
        #expect(DayCountPhrase.key(for: 3, isArabic: true) == .dayCountFew)
        #expect(DayCountPhrase.key(for: 10, isArabic: true) == .dayCountFew)
        #expect(DayCountPhrase.key(for: 11, isArabic: true) == .dayCountMany)
        #expect(DayCountPhrase.key(for: 0, isArabic: true) == .dayCountFew)
    }

    @Test func englishUsesOneOrNDays() {
        #expect(DayCountPhrase.key(for: 1, isArabic: false) == .dayCountOne)
        #expect(DayCountPhrase.key(for: 11, isArabic: false) == .dayCountFew)
    }

    @Test func rangesAreWrittenOnceInsideAMonthAndTwiceAcrossOne() {
        func text(_ a: HijriDate, _ b: HijriDate) -> String {
            OccasionDateText.hijri(first: a, last: b, localized: { "\($0.rawValue)" }, number: { n, _ in "\(n)" })
        }
        let nine = HijriDate(day: 9, month: .muharram, year: 1447)
        let ten = HijriDate(day: 10, month: .muharram, year: 1447)
        let thirty = HijriDate(day: 30, month: .shaban, year: 1447)
        let first = HijriDate(day: 1, month: .ramadan, year: 1447)

        #expect(text(ten, ten) == "10 hijri_month_muharram 1447")
        #expect(text(nine, ten) == "9–10 hijri_month_muharram 1447")
        #expect(text(thirty, first) == "30 hijri_month_shaban 1447 – 1 hijri_month_ramadan 1447")
    }

    // MARK: Occasions

    @Test func upcomingStartsWithWhatIsNextAndCountsDays() throws {
        let (calendar, _) = makeModels()

        // From 2 July 2025 (7 Muharram 1447): Ashura (9–10 Muharram) is next, two days off.
        let first = try #require(calendar.upcoming(limit: 3).first)
        #expect(first.occasion.id == "ashura")
        #expect(calendar.daysAway(to: first) == 2)
        #expect(calendar.upcoming(limit: 3).count == 3)
        #expect(calendar.upcoming(limit: 3).allSatisfy { !$0.occasion.isRecurring })
    }

    @Test func theYearListHasNoRecurringFastsAndIsInOrder() {
        let (calendar, _) = makeModels()
        let year = calendar.occurrences(inYear: 1447)

        #expect(!year.isEmpty)
        #expect(year.allSatisfy { !$0.occasion.isRecurring })
        #expect(year.map(\.first.gregorian) == year.map(\.first.gregorian).sorted())
        #expect(year.contains { $0.occasion.id == "eid_al_fitr" })
    }

    // MARK: The moon screen

    @Test func theStripHasEightPhasesInOrder() {
        let (_, detail) = makeModels()
        let phases = detail.phases.map(\.phase)

        #expect(phases == MoonPhase.allCases)
        #expect(detail.phases.first?.illuminatedFraction ?? 1 < 0.05)
    }

    @Test func jumpingToAPhaseSelectsItsFirstDayAndMovesTheCalendar() throws {
        let (calendar, detail) = makeModels()

        let full = try #require(detail.jump(to: .fullMoon))
        #expect(calendar.selectedDay == full)
        #expect(calendar.moon(on: full).phase == .fullMoon)
        #expect(calendar.moon(on: calendar.day(byAdding: -1, to: full)).phase != .fullMoon)
        // Full moon is 10 July 2025; the phase begins a day or two before.
        #expect(full >= date(2025, 7, 7) && full <= date(2025, 7, 10))
    }

    @Test func jumpingToThePhaseYouAreInGoesToTheNextCycle() throws {
        let (calendar, detail) = makeModels()
        let first = try #require(detail.jump(to: .fullMoon))
        let again = try #require(detail.jump(to: .fullMoon))

        let gap = calendar.daysFromToday(to: again) - calendar.daysFromToday(to: first)
        #expect((27...31).contains(gap))
    }

    @Test func nextEventsAreAfterNow() {
        let (_, detail) = makeModels()
        let events = detail.events

        #expect(events.fullMoon > date(2025, 7, 2))
        #expect(events.newMoon > date(2025, 7, 2))
        #expect(detail.daysUntil(events.fullMoon) >= 7)
    }
}
