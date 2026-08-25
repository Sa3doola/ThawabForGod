//
//  PrayerTimesSheetViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The one thing this screen has that Home does not: a date the user can move.
@MainActor
struct PrayerTimesSheetViewModelTests {

    private let today = PrayerTimeFixtures.day(2026, 6, 15)
    private let tomorrow = PrayerTimeFixtures.day(2026, 6, 16)

    private func makeViewModel(
        at now: Date? = nil,
        days: [Date]? = nil
    ) -> (PrayerTimesSheetViewModel, TestClock) {
        let instant = now ?? PrayerTimeFixtures.instant(today, hour: 13)
        let clock = TestClock(instant)

        let viewModel = PrayerTimesSheetViewModel(
            useCase: GetPrayerScheduleUseCase(
                repository: PrayerTimeFixtures.repository(days: days ?? [today, tomorrow]),
                calendar: PrayerTimeFixtures.calendar
            ),
            calculation: CalculationSettings(config: .default, settingsStore: InMemorySettingsStore()),
            hijriDates: StubHijriDateService(),
            coordinates: { .makkah },
            clock: clock,
            calendar: PrayerTimeFixtures.calendar
        )

        return (viewModel, clock)
    }

    @Test func itOpensOnToday() {
        let (viewModel, _) = makeViewModel()

        #expect(viewModel.day == today)
        #expect(viewModel.isToday)
    }

    @Test func tappingADayInTheStripSelectsIt() {
        let (viewModel, _) = makeViewModel()

        viewModel.select(tomorrow)

        #expect(viewModel.day == tomorrow)
        #expect(viewModel.isToday == false)
        #expect(viewModel.isSelected(tomorrow))
        #expect(viewModel.isSelected(today) == false)
    }

    /// Today keeps its own mark whichever day is selected — the two are separate questions, which
    /// is why the strip asks them separately.
    @Test func todayIsMarkedEvenWhenAnotherDayIsSelected() {
        let (viewModel, _) = makeViewModel()

        viewModel.select(tomorrow)

        #expect(viewModel.isCurrentDay(today))
        #expect(viewModel.isCurrentDay(tomorrow) == false)
    }

    @Test func theChevronsPageAWholeWeek() {
        let (viewModel, _) = makeViewModel()

        viewModel.showNextWeek()

        #expect(viewModel.day == PrayerTimeFixtures.day(2026, 6, 22))

        viewModel.showPreviousWeek()
        viewModel.showPreviousWeek()

        #expect(viewModel.day == PrayerTimeFixtures.day(2026, 6, 8))
    }

    /// Seven days, running from whatever weekday the calendar starts on, and containing the day
    /// on screen.
    @Test func theStripIsTheWeekAroundTheSelectedDay() throws {
        let (viewModel, _) = makeViewModel()
        let week = viewModel.week

        #expect(week.count == 7)
        #expect(week.contains(today))
        #expect(PrayerTimeFixtures.calendar.component(.weekday, from: try #require(week.first))
            == PrayerTimeFixtures.calendar.firstWeekday)
    }

    @Test func theTodayButtonComesBack() {
        let (viewModel, _) = makeViewModel()

        viewModel.showNextWeek()
        viewModel.showToday()

        #expect(viewModel.day == today)
        #expect(viewModel.isToday)
    }

    /// Selecting lands on midnight whatever hour the sheet was opened at, so a day is one day
    /// rather than "twenty-four hours from when you looked".
    @Test func selectingLandsOnMidnight() {
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 23, minute: 45))

        viewModel.select(PrayerTimeFixtures.instant(tomorrow, hour: 9, minute: 30))

        #expect(viewModel.day == tomorrow)
    }

    @Test func loadingComputesTheShownDay() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()

        guard case .ready(let schedule) = viewModel.phase else {
            Issue.record("expected a computed day, got \(viewModel.phase)")
            return
        }

        #expect(schedule.day == today)
        #expect(schedule.times.count == 6)
    }

    @Test func aDayThatCannotBeComputedSaysSo() async {
        let (viewModel, _) = makeViewModel(days: [today])

        viewModel.select(tomorrow)
        await viewModel.load()

        #expect(viewModel.phase == .unavailable)
    }

    /// Without a tracker the circles are simply absent, and marking does nothing rather than
    /// trapping.
    @Test func withoutATrackerNothingIsMarked() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.setCompleted(true, of: .asr)

        #expect(viewModel.record.completed.isEmpty)
        #expect(viewModel.streak == 0)
    }

    @Test func markingAPrayerOnTheShownDayIsRecorded() async throws {
        let persistence = try PersistenceController(inMemory: true)
        let repository = PrayerTrackerRepository(modelContainer: persistence.container)
        let clock = TestClock(PrayerTimeFixtures.instant(today, hour: 13))

        let viewModel = PrayerTimesSheetViewModel(
            useCase: GetPrayerScheduleUseCase(
                repository: PrayerTimeFixtures.repository(days: [today, tomorrow]),
                calendar: PrayerTimeFixtures.calendar
            ),
            tracker: PrayerTrackerUseCase(
                repository: repository,
                calendar: PrayerTimeFixtures.calendar
            ),
            calculation: CalculationSettings(config: .default, settingsStore: InMemorySettingsStore()),
            hijriDates: StubHijriDateService(),
            coordinates: { .makkah },
            clock: clock,
            calendar: PrayerTimeFixtures.calendar
        )

        await viewModel.setCompleted(true, of: .asr)

        #expect(viewModel.record.completed == [.asr])
        #expect(try await repository.record(on: today).completed == [.asr])
    }
}
