//
//  HijriCalendarServiceTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct HijriCalendarServiceTests {

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Self.gregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func service(offset: Int = 0) -> HijriCalendarService {
        HijriCalendarService(timeZone: .gmt, dayOffset: { offset })
    }

    @Test func everyMonthHasTwentyNineOrThirtyDays() {
        let service = service()
        var key = HijriMonthKey(year: 1446, month: .muharram)
        for _ in 0..<36 {
            let grid = service.monthGrid(for: key, firstWeekday: 7)
            #expect([29, 30].contains(grid?.days.count ?? 0))
            key = key.next
        }
    }

    /// 1 Muharram 1447 is 26 June 2025 in Umm al-Qura, a Thursday.
    @Test func dayOneLandsOnItsCivilDateAndWeekday() throws {
        let grid = try #require(service().monthGrid(for: .init(year: 1447, month: .muharram), firstWeekday: 7))
        #expect(grid.days[0].gregorian == date(2025, 6, 26))
        // Saturday-first: Sat, Sun, Mon, Tue, Wed are blank before Thursday.
        #expect(grid.leadingBlanks == 5)
        #expect(grid.cells.count == 5 + grid.days.count)
        // Sunday-first: Thursday is the fifth column.
        let sunday = try #require(service().monthGrid(for: .init(year: 1447, month: .muharram), firstWeekday: 1))
        #expect(sunday.leadingBlanks == 4)
    }

    @Test func offsetMovesDatesNotMonthLength() throws {
        let key = HijriMonthKey(year: 1447, month: .muharram)
        let base = try #require(service().monthGrid(for: key, firstWeekday: 7))
        let shifted = try #require(service(offset: 1).monthGrid(for: key, firstWeekday: 7))
        #expect(shifted.days.count == base.days.count)
        #expect(shifted.days[0].gregorian == date(2025, 6, 25))
    }

    /// 26 June 2025 is 1 Muharram 1447 (a Thursday). Saturday-first, a Thursday starts the
    /// sixth column (5 blanks); +2 pulls day 1 back to Tuesday (3 blanks), −2 pushes it to
    /// Saturday (0 blanks).
    @Test(arguments: [
        (offset: 2, civilDay1: (2025, 6, 24), blanks: 3, todayCell: 3 + 2),
        (offset: -2, civilDay1: (2025, 6, 28), blanks: 0, todayCell: nil as Int?),
    ])
    func extremeOffsetsMoveDayOneAndToday(
        offset: Int, civilDay1: (Int, Int, Int), blanks: Int, todayCell: Int?
    ) throws {
        let service = service(offset: offset)
        let today = date(2025, 6, 26)
        let key = HijriMonthKey(year: 1447, month: .muharram)
        let grid = try #require(service.monthGrid(for: key, firstWeekday: 7))

        #expect(grid.days[0].gregorian == date(civilDay1.0, civilDay1.1, civilDay1.2))
        #expect(grid.leadingBlanks == blanks)
        #expect(grid.cellIndex(containing: today, calendar: Self.gregorian) == todayCell)

        // Wherever "today" is not in Muharram it is in the month the service names for it.
        let todayKey = service.monthKey(containing: today)
        let todayGrid = try #require(service.monthGrid(for: todayKey, firstWeekday: 7))
        #expect(todayGrid.cellIndex(containing: today, calendar: Self.gregorian) != nil)
        if offset == -2 { #expect(todayKey == key.previous) }
    }

    @Test func offsetAppliesToTheMonthContainingADate() {
        // 26 June 2025 is 1 Muharram; with +1 the previous civil day (25 June) is too, so the
        // reader whose calendar runs a day ahead is already in Muharram on the 25th.
        #expect(service(offset: 1).monthKey(containing: date(2025, 6, 25)) == .init(year: 1447, month: .muharram))
        #expect(service(offset: 0).monthKey(containing: date(2025, 6, 25)) == .init(year: 1446, month: .dhulHijjah))
    }

    @Test func navigationWrapsYearsAndStopsOutsideTheSupportedRange() {
        #expect(HijriMonthKey(year: 1446, month: .dhulHijjah).next == .init(year: 1447, month: .muharram))
        #expect(HijriMonthKey(year: 1447, month: .muharram).previous == .init(year: 1446, month: .dhulHijjah))
        #expect(service().monthGrid(for: .init(year: 1501, month: .muharram), firstWeekday: 1) == nil)
        #expect(service().monthGrid(for: .init(year: 1317, month: .dhulHijjah), firstWeekday: 1) == nil)
    }

    @Test func serviceAppliesOffsetToHijriDate() {
        let plain = HijriDateService(timeZone: .gmt, events: [])
        let ahead = HijriDateService(timeZone: .gmt, events: [], dayOffset: { 1 })
        #expect(plain.hijriComponents(for: date(2025, 6, 25)).month == .dhulHijjah)
        #expect(ahead.hijriComponents(for: date(2025, 6, 25))
            == HijriDate(day: 1, month: .muharram, year: 1447))
    }

    @Test func offsetIsClamped() {
        #expect(HijriDayOffset.clamp(9) == 2)
        #expect(HijriDayOffset.clamp(-9) == -2)
    }
}
