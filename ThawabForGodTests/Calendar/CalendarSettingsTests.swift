//
//  CalendarSettingsTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct CalendarSettingsTests {

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Self.gregorian.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: The offset

    @Test func theOffsetIsWrittenOnlyWhenChosenAndClamped() {
        let store = InMemorySettingsStore()
        let model = HijriCalendarViewModel.testing(store: store)

        #expect(model.dayOffset == 0)
        #expect(store.double(for: .hijriDayOffset) == nil)

        model.setDayOffset(0)
        #expect(store.double(for: .hijriDayOffset) == nil)

        model.setDayOffset(9)
        #expect(model.dayOffset == 2)
        #expect(store.double(for: .hijriDayOffset) == 2)

        model.setDayOffset(-5)
        #expect(model.dayOffset == -2)
    }

    @Test func changingTheOffsetTellsWhoDrewTheOldDate() {
        var notified = 0
        let model = HijriCalendarViewModel.testing(onOffsetChange: { notified += 1 })

        model.setDayOffset(1)
        model.setDayOffset(1)   // not a change
        model.setDayOffset(-1)

        #expect(notified == 2)
    }

    @Test func theCalendarFollowsTheOffsetItIsGiven() {
        let model = HijriCalendarViewModel.testing()
        let before = model.hijriDate(of: date(2025, 7, 2))

        model.setDayOffset(1)

        #expect(model.hijriDate(of: date(2025, 7, 2)).day == before.day + 1)
    }

    @Test func aStoredOffsetIsReadAtStart() {
        let model = HijriCalendarViewModel.testing(store: InMemorySettingsStore(doubles: [.hijriDayOffset: -1]))

        #expect(model.dayOffset == -1)
    }

    @Test func eachOffsetHasItsOwnLabel() {
        let l10n = LocalizationManager(
            settingsStore: InMemorySettingsStore(),
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService(),
            language: .english
        )
        let labels = [-2, -1, 0, 1, 2].map { l10n.offsetLabel($0) }

        #expect(Set(labels).count == 5)
        #expect(labels == ["Delay 2 days", "Delay 1 day", "No adjustment", "Advance 1 day", "Advance 2 days"])
    }

    // MARK: The dots

    @Test func hidingRecurringDotsRemovesOnlyTheQuietOnes() throws {
        let store = InMemorySettingsStore()
        let model = HijriCalendarViewModel.testing(store: store)
        let grid = try #require(model.grid(for: HijriMonthKey(year: 1447, month: .muharram)))

        #expect(model.markers(in: grid)[date(2025, 6, 30)]?.hasRecurring == true)

        model.hideRecurringDots = true

        let markers = model.markers(in: grid)
        #expect(markers[date(2025, 6, 30)] == nil)
        #expect(markers[date(2025, 7, 5)]?.hasOccasion == true)
        #expect(store.bool(for: .hideRecurringDots) == true)
        #expect(HijriCalendarViewModel.testing(store: store).hideRecurringDots)
    }

    // MARK: The route

    @Test func theCalendarHasARowInSettingsOnBothPlatforms() {
        #expect(SettingsRoute.root.contains(.calendar))
        #expect(SettingsRoute.calendar.titleKey == .calendarTitle)
    }
}
