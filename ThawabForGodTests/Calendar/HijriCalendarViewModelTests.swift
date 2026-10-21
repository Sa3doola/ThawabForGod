//
//  HijriCalendarViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import SwiftUI // NavigationPath.count
import Testing
@testable import ThawabForGod

@MainActor
struct HijriCalendarViewModelTests {

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Self.gregorian.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// Wednesday 2 July 2025, which is 7 Muharram 1447 on Umm al-Qura with no offset.
    private func makeViewModel(
        store: InMemorySettingsStore = InMemorySettingsStore(),
        offset: Int = 0
    ) -> HijriCalendarViewModel {
        let months = HijriCalendarService(timeZone: .gmt, dayOffset: { offset })
        return HijriCalendarViewModel(
            calendar: months,
            occasions: ResolveOccasionDatesUseCase(
                repository: BundledOccasionsRepository(),
                calendar: months,
                dayOffset: { offset }
            ),
            moon: GetMoonInfoUseCase(
                moon: AstronomicalMoonCalculator(),
                schedule: GetPrayerScheduleUseCase(repository: PrayerTimeRepository(engine: PrayerTimeEngine()))
            ),
            hijriDates: HijriDateService(timeZone: .gmt, dayOffset: { offset }),
            settingsStore: store,
            coordinates: { .makkah },
            config: { .default },
            clock: TestClock(date(2025, 7, 2).addingTimeInterval(12 * 3600)),
            timeZone: .gmt,
            locale: Locale(identifier: "en_US")
        )
    }

    // MARK: Where it starts

    @Test func startsOnTodaysMonthWithTodaySelected() {
        let model = makeViewModel()

        #expect(model.visibleMonth == HijriMonthKey(year: 1447, month: .muharram))
        #expect(model.selectedDay == date(2025, 7, 2))
        #expect(model.isToday(date(2025, 7, 2)))
        #expect(model.hijriDate(of: model.selectedDay).day == 7)
    }

    @Test func revealingADayBringsItsMonthIntoView() {
        let model = makeViewModel()

        model.reveal(date(2025, 9, 1))

        #expect(model.visibleMonth.month == .rabiAlAwwal)
        #expect(model.isSelected(date(2025, 9, 1)))

        model.goToToday()
        #expect(model.visibleMonth == HijriMonthKey(year: 1447, month: .muharram))
        #expect(model.selectedDay == date(2025, 7, 2))
    }

    @Test func steppingMovesByMonthsAndStopsAtTheEnds() {
        let model = makeViewModel()

        model.step(by: 1)
        #expect(model.visibleMonth == HijriMonthKey(year: 1447, month: .safar))
        model.step(by: -2)
        #expect(model.visibleMonth == HijriMonthKey(year: 1446, month: .dhulHijjah))

        model.show(HijriMonthKey(year: 1600, month: .muharram))
        #expect(model.visibleMonth == HijriMonthKey(year: 1446, month: .dhulHijjah))
        #expect(model.months.first == HijriMonthKey(year: model.supportedYears.lowerBound, month: .muharram))
        #expect(model.months.count == model.supportedYears.count * 12)
    }

    // MARK: Markers

    @Test func ashuraGetsTheLoudDotAndMondaysTheQuietOne() throws {
        let model = makeViewModel()
        let grid = try #require(model.grid(for: HijriMonthKey(year: 1447, month: .muharram)))
        let markers = model.markers(in: grid)

        // 10 Muharram 1447 is Saturday 5 July 2025.
        #expect(markers[date(2025, 7, 5)]?.hasOccasion == true)
        // Monday 30 June is 4 Muharram: nothing but the weekly fast.
        #expect(markers[date(2025, 6, 30)] == DayMarker(hasOccasion: false, hasRecurring: true))
        // Tuesday 1 July carries nothing at all.
        #expect(markers[date(2025, 7, 1)] == nil)
    }

    @Test func occasionsOnADayListOneOffsFirst() {
        let model = makeViewModel()

        let ids = model.occasions(on: date(2025, 7, 5)).map(\.id)
        #expect(ids.first == "ashura")

        // Monday 30 June: only the recurring fast.
        #expect(model.occasions(on: date(2025, 6, 30)).map(\.id) == ["monday_thursday"])
    }

    @Test func theOffsetMovesTheMarkersToo() throws {
        let model = makeViewModel(offset: 1)
        let grid = try #require(model.grid(for: HijriMonthKey(year: 1447, month: .muharram)))
        let markers = model.markers(in: grid)

        // With the label a day ahead, 10 Muharram is a civil day earlier.
        #expect(markers[date(2025, 7, 4)]?.hasOccasion == true)
        #expect(model.hijriDate(of: date(2025, 7, 4)).day == 10)
    }

    // MARK: Layout and preferences

    @Test func theWeekStartDecidesTheColumnsAndTheBlanks() throws {
        let model = makeViewModel()
        let key = HijriMonthKey(year: 1447, month: .muharram)

        model.weekStart = .sunday
        #expect(model.columnWeekdays == [1, 2, 3, 4, 5, 6, 7])
        // 1 Muharram 1447 is Thursday 26 June 2025.
        #expect(try #require(model.grid(for: key)).leadingBlanks == 4)

        model.weekStart = .monday
        #expect(model.columnWeekdays == [2, 3, 4, 5, 6, 7, 1])
        #expect(try #require(model.grid(for: key)).leadingBlanks == 3)

        model.weekStart = .saturday
        #expect(model.columnWeekdays.first == 7)
        #expect(try #require(model.grid(for: key)).leadingBlanks == 5)
    }

    @Test func preferencesAreWrittenOnlyWhenChosen() {
        let store = InMemorySettingsStore()
        let model = makeViewModel(store: store)

        #expect(model.showGregorian == false)
        #expect(model.weekStart == .locale)
        #expect(store.bool(for: .showGregorianInCalendar) == nil)
        #expect(store.string(for: .calendarWeekStart) == nil)

        model.showGregorian = false
        #expect(store.bool(for: .showGregorianInCalendar) == nil)

        model.showGregorian = true
        model.weekStart = .monday
        #expect(store.bool(for: .showGregorianInCalendar) == true)
        #expect(store.string(for: .calendarWeekStart) == "monday")

        #expect(makeViewModel(store: store).showGregorian)
        #expect(makeViewModel(store: store).weekStart == .monday)
    }

    // MARK: The moon

    @Test func theMoonIsReadAtMaghribOfTheDay() {
        let model = makeViewModel()

        // Full moon on 10 July 2025 (~20:36 UTC); read at Maghrib the same evening.
        let full = model.moon(on: date(2025, 7, 10))
        #expect(full.illuminatedFraction > 0.97)
        #expect(full.phase == .fullMoon)

        let new = model.moon(on: date(2025, 6, 25))
        #expect(new.illuminatedFraction < 0.03)
    }
}

@MainActor
struct HijriOffsetWiringTests {

    @Test func theContainersHijriDateFollowsTheStoredOffset() throws {
        func container(offset: Double?) throws -> AppContainer {
            AppContainer(
                settingsStore: InMemorySettingsStore(
                    bools: [.onboardingCompleted: true],
                    doubles: offset.map { [.hijriDayOffset: $0] } ?? [:]
                ),
                persistence: try PersistenceController(inMemory: true),
                locationService: MockLocationService(),
                notificationService: MockNotificationService(),
                registersBackgroundRefresh: false
            )
        }
        let day = Date(timeIntervalSince1970: 1_751_457_600) // 2 July 2025, 12:00 UTC

        let plain = try container(offset: nil).hijriDates.hijriComponents(for: day)
        let shifted = try container(offset: 2).hijriDates.hijriComponents(for: day)

        #expect(shifted.day == plain.day + 2)
    }

    @Test func theCalendarLinkPushesTheCalendarOntoHome() throws {
        let container = AppContainer(
            settingsStore: InMemorySettingsStore(bools: [.onboardingCompleted: true]),
            persistence: try PersistenceController(inMemory: true),
            locationService: MockLocationService(),
            notificationService: MockNotificationService(),
            registersBackgroundRefresh: false
        )
        container.router.selectedTab = .quran

        container.open(DeepLink.calendar)
        #expect(container.router.selectedTab == .home)
        #expect(container.homeCoordinator.path.count == 1)

        // Opening it again replaces rather than stacks.
        container.open(DeepLink.calendar)
        #expect(container.homeCoordinator.path.count == 1)
    }
}
