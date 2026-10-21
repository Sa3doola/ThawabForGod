//
//  IslamicOccasionsTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct IslamicOccasionsTests {

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Self.gregorian.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private let repository = BundledOccasionsRepository()

    private func resolver(offset: Int = 0) -> ResolveOccasionDatesUseCase {
        ResolveOccasionDatesUseCase(
            repository: repository,
            calendar: HijriCalendarService(timeZone: .gmt, dayOffset: { offset }),
            dayOffset: { offset }
        )
    }

    private func occurrences(_ id: String, year: Int = 1447, offset: Int = 0) -> [OccasionOccurrence] {
        resolver(offset: offset)(hijriYear: year).filter { $0.occasion.id == id }
    }

    // MARK: The bundled table

    @Test func theTableDecodesWithUniqueIds() {
        let all = repository.occasions()
        #expect(all.count == 18)
        #expect(Set(all.map(\.id)).count == all.count)
    }

    /// The original ten entries must keep their meaning: same ids, same single day.
    @Test func existingEntriesKeepTheirIdsMonthsAndDays() {
        let events = IslamicEventTable.bundled()
        let expected: [String: (Int, Int)] = [
            "islamic_new_year": (1, 1), "ashura": (1, 10), "mawlid": (3, 12), "isra_miraj": (7, 27),
            "nisf_shaban": (8, 15), "ramadan_start": (9, 1), "laylat_al_qadr": (9, 27),
            "eid_al_fitr": (10, 1), "arafah": (12, 9), "eid_al_adha": (12, 10),
        ]
        #expect(events.count == 10)
        for event in events {
            #expect(expected[event.id]?.0 == event.month.rawValue)
            #expect(expected[event.id]?.1 == event.day)
        }
    }

    /// Accuracy rule: a virtue text always has a source, and every source carries a grading.
    @Test func everyVirtueIsSourcedAndGraded() {
        for occasion in repository.occasions() where occasion.virtueKey != nil {
            #expect(!occasion.sources.isEmpty, "\(occasion.id) has a virtue and no source")
            #expect(occasion.sources.allSatisfy { $0.grading != nil }, "\(occasion.id) has an ungraded source")
        }
    }

    @Test func contestedOccasionsCarryAScholarlyNote() {
        let noted = Set(repository.occasions().filter { $0.scholarlyNoteKey != nil }.map(\.id))
        #expect(noted.isSuperset(of: ["mawlid", "isra_miraj", "nisf_shaban", "laylat_al_qadr"]))
    }

    // MARK: Rules, resolved for 1447 AH (1 Muharram = 26 June 2025; 10 Dhul Hijjah = 27 May 2026)

    @Test func fixedDay() throws {
        let eid = try #require(occurrences("eid_al_adha").first)
        #expect(eid.days.count == 1)
        #expect(eid.first.gregorian == date(2026, 5, 27))
        #expect(eid.first.hijri == HijriDate(day: 10, month: .dhulHijjah, year: 1447))
    }

    @Test func dayRange() throws {
        let ashura = try #require(occurrences("ashura").first)
        #expect(ashura.days.map(\.hijri.day) == [9, 10])
        #expect(ashura.last.gregorian == date(2025, 7, 5))

        let tashreeq = try #require(occurrences("tashreeq").first)
        #expect(tashreeq.days.map(\.hijri.day) == [11, 12, 13])
        #expect(tashreeq.days.allSatisfy { $0.hijri.month == .dhulHijjah })

        // A range may name a day the month does not have (the thirtieth); it just stops.
        let lastTen = occurrences("last_ten_nights")
        #expect(lastTen.count == 1)
        #expect((9...10).contains(lastTen[0].days.count))
        #expect(lastTen[0].first.hijri.day == 21)
    }

    @Test func oddNights() throws {
        let nights = try #require(occurrences("laylat_al_qadr").first)
        #expect(nights.days.map(\.hijri.day) == [21, 23, 25, 27, 29])
        #expect(nights.days.allSatisfy { $0.hijri.month == .ramadan })
    }

    @Test func monthlyDaysOnceAMonth() {
        let white = occurrences("ayyam_al_bid")
        #expect(white.count == 12)
        #expect(white.allSatisfy { $0.days.map(\.hijri.day) == [13, 14, 15] })
    }

    @Test func weeklyIsMondaysAndThursdays() {
        let fasts = occurrences("monday_thursday")
        #expect((98...106).contains(fasts.count))
        for fast in fasts {
            let weekday = Self.gregorian.component(.weekday, from: fast.first.gregorian)
            #expect([2, 5].contains(weekday))
        }
    }

    @Test func offsetMovesEveryResolvedDate() throws {
        let plain = try #require(occurrences("eid_al_adha").first)
        let ahead = try #require(occurrences("eid_al_adha", offset: 1).first)
        #expect(ahead.first.gregorian == plain.first.gregorian.addingTimeInterval(-86_400))
        #expect(ahead.first.hijri == plain.first.hijri)
    }

    // MARK: Upcoming

    @Test func upcomingWrapsIntoTheNextHijriYear() throws {
        let service = HijriCalendarService(timeZone: .gmt)
        let upcoming = GetUpcomingOccasionsUseCase(resolve: resolver(), calendar: service, gregorian: Self.gregorian)

        // 10 June 2026 is late in Dhul Hijjah 1447; the next thing is 1 Muharram 1448.
        let list = upcoming(from: date(2026, 6, 10), limit: 3)
        #expect(list.count == 3)
        let first = try #require(list.first)
        #expect(first.occasion.id == "islamic_new_year")
        #expect(first.first.hijri.year == 1448)
        #expect(list.allSatisfy { !$0.occasion.isRecurring })
    }

    @Test func aRangeUnderWayIsStillUpcomingAndRecurringCanBeAsked() {
        let service = HijriCalendarService(timeZone: .gmt)
        let upcoming = GetUpcomingOccasionsUseCase(resolve: resolver(), calendar: service, gregorian: Self.gregorian)

        // 5 July 2025 is the tenth of Muharram: the last day of the Ashura range.
        let list = upcoming(from: date(2025, 7, 5), limit: 1)
        #expect(list.first?.occasion.id == "ashura")

        let withRecurring = upcoming(from: date(2025, 7, 5), limit: 3, includeRecurring: true)
        #expect(withRecurring.contains { $0.occasion.isRecurring })
    }

    // MARK: Rule coding

    @Test func rulesRoundTrip() throws {
        let rules: [OccasionRule] = [
            .fixedDay(month: 1, day: 1), .dayRange(month: 1, from: 9, to: 10), .monthlyDays([13, 14, 15]),
            .weekly(weekdays: [2, 5]), .oddNights(month: 9, days: [21, 23]),
        ]
        for rule in rules {
            let data = try JSONEncoder().encode(rule)
            #expect(try JSONDecoder().decode(OccasionRule.self, from: data) == rule)
        }
    }
}
