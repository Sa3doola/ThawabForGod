//
//  HomeViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct HomeViewModelTests {

    private let today = PrayerTimeFixtures.day(2026, 6, 15)
    private let tomorrow = PrayerTimeFixtures.day(2026, 6, 16)

    private func makeViewModel(
        at now: Date,
        days: [Date]? = nil,
        failure: PrayerTimeError? = nil,
        hijriDates: any HijriDateServicing = StubHijriDateService(),
        calculation: CalculationSettings? = nil,
        tips: any HomeTipReporting = SpyHomeTipReporter(),
        placeNames: (any PlaceNameResolving)? = nil,
        reachability: (any NetworkReachability)? = nil
    ) -> (HomeViewModel, TestClock) {
        let repository: StubPrayerTimeRepository = if let failure {
            StubPrayerTimeRepository(failure: failure)
        } else {
            PrayerTimeFixtures.repository(days: days ?? [today, tomorrow])
        }

        let clock = TestClock(now)
        let viewModel = HomeViewModel(
            useCase: GetPrayerScheduleUseCase(
                repository: repository,
                calendar: PrayerTimeFixtures.calendar
            ),
            coordinates: .makkah,
            placeNames: placeNames,
            reachability: reachability,
            hijriDates: hijriDates,
            calculation: calculation ?? CalculationSettings(
                config: .default,
                settingsStore: InMemorySettingsStore()
            ),
            tips: tips,
            clock: clock,
            // The fixtures are pinned to GMT, and the day boundary is what the roll-over tests
            // turn on — inheriting the machine's zone would make them pass or fail by geography.
            calendar: PrayerTimeFixtures.calendar
        )

        return (viewModel, clock)
    }

    private func ready(_ viewModel: HomeViewModel) throws -> NextPrayerState {
        guard case .ready(let state) = viewModel.phase else {
            Issue.record("expected a loaded day, got \(viewModel.phase)")
            throw CancellationError()
        }
        return state
    }

    // MARK: Loading

    @Test func itStartsLoading() {
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 13))

        #expect(viewModel.phase == .loading)
    }

    @Test func refreshingPublishesTheDayTheCurrentPrayerAndTheNext() throws {
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 13))

        viewModel.refresh()
        let state = try ready(viewModel)

        #expect(state.schedule.times.count == 6)
        #expect(state.currentPrayer == .dhuhr)
        #expect(state.upcoming.prayer == .asr)
        #expect(state.upcoming.isTomorrow == false)
    }

    @Test func theCountdownIsTheGapToTheNextPrayer() throws {
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 13))

        viewModel.refresh()

        // 13:00 → asr at 15:30 is two and a half hours.
        #expect(viewModel.countdown == 2.5 * 3600)
    }

    @Test func aFailureToComputeBecomesTheUnavailableState() {
        let (viewModel, _) = makeViewModel(
            at: PrayerTimeFixtures.instant(today, hour: 13),
            failure: .notComputable(today)
        )

        viewModel.refresh()

        #expect(viewModel.phase == .unavailable)
        #expect(viewModel.countdown == 0)
    }

    // MARK: Ticking

    @Test func tickingFollowsTheClockDown() throws {
        let (viewModel, clock) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 15))

        viewModel.refresh()
        #expect(viewModel.countdown == 30 * 60)

        clock.advance(by: 60)
        viewModel.tick()

        #expect(viewModel.countdown == 29 * 60)
        // Still the same prayer, so the loaded day is untouched.
        #expect(try ready(viewModel).upcoming.prayer == .asr)
    }

    @Test func tickingPastAPrayerRetargetsTheCountdown() throws {
        let (viewModel, clock) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 15, minute: 29))

        viewModel.refresh()
        #expect(try ready(viewModel).upcoming.prayer == .asr)

        // Step over Asr.
        clock.move(to: PrayerTimeFixtures.instant(today, hour: 15, minute: 31))
        viewModel.tick()

        let state = try ready(viewModel)
        #expect(state.currentPrayer == .asr)
        #expect(state.upcoming.prayer == .maghrib)
        #expect(viewModel.countdown == (2 * 3600) + (29 * 60))
    }

    @Test func tickingDoesNothingWhileUnavailable() {
        let (viewModel, clock) = makeViewModel(
            at: PrayerTimeFixtures.instant(today, hour: 13),
            failure: .notComputable(today)
        )

        viewModel.refresh()
        clock.advance(by: 60)
        viewModel.tick()

        #expect(viewModel.phase == .unavailable)
    }

    // MARK: After Isha

    @Test func afterIshaTheCountdownTargetsTomorrowsFajr() throws {
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 22))

        viewModel.refresh()
        let state = try ready(viewModel)

        #expect(state.currentPrayer == .isha)
        #expect(state.upcoming.prayer == .fajr)
        #expect(state.upcoming.isTomorrow)
        // 22:00 → 05:00 the next morning.
        #expect(viewModel.countdown == 7 * 3600)
    }

    /// The row highlight and the countdown must not disagree: after Isha the countdown says
    /// "Fajr", but *today's* Fajr row is long past and must not be marked as next.
    @Test func tomorrowsFajrDoesNotHighlightTodaysFajrRow() throws {
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 22))

        viewModel.refresh()
        let state = try ready(viewModel)

        #expect(state.isUpcoming(.fajr) == false)
        #expect(state.isCurrent(.isha))
    }

    @Test func beforeFajrNothingIsCurrentAndFajrIsNext() throws {
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 3))

        viewModel.refresh()
        let state = try ready(viewModel)

        #expect(state.currentPrayer == nil)
        #expect(state.upcoming.prayer == .fajr)
        #expect(state.isUpcoming(.fajr))
        #expect(viewModel.countdown == 2 * 3600)
    }

    // MARK: Hijri header

    /// Available from construction, before anything has been refreshed — the header must not
    /// wait for the loading state to clear.
    @Test func theHijriDateIsResolvedBeforeTheFirstRefresh() {
        let hijri = StubHijriDateService(
            hijriDate: HijriDate(day: 10, month: .muharram, year: 1447),
            events: [.stub(id: "ashura")]
        )
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 13), hijriDates: hijri)

        #expect(viewModel.phase == .loading)
        #expect(viewModel.hijriDate == HijriDate(day: 10, month: .muharram, year: 1447))
        #expect(viewModel.todaysEvents.map(\.id) == ["ashura"])
    }

    @Test func mostDaysCarryNoEvents() {
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 13))

        viewModel.refresh()

        #expect(viewModel.todaysEvents.isEmpty)
    }

    /// The date is not part of `Phase`, so it survives the times failing to compute — a screen
    /// that cannot show prayer times should still know what day it is.
    @Test func theHijriDateSurvivesAnUnavailableDay() {
        let hijri = StubHijriDateService(
            hijriDate: HijriDate(day: 1, month: .ramadan, year: 1447),
            events: [.stub(id: "ramadan_start", noteKey: .eventNoteMoonSighting, month: .ramadan, day: 1)]
        )
        let (viewModel, _) = makeViewModel(
            at: PrayerTimeFixtures.instant(today, hour: 13),
            failure: .notComputable(today),
            hijriDates: hijri
        )

        viewModel.refresh()

        #expect(viewModel.phase == .unavailable)
        #expect(viewModel.hijriDate == HijriDate(day: 1, month: .ramadan, year: 1447))
        #expect(viewModel.todaysEvents.first?.noteKey == .eventNoteMoonSighting)
    }

    // MARK: Calculation settings

    /// The window onto the shared object, which is what the view watches for a change.
    @Test func theConfigIsReadThroughRatherThanCopied() {
        let calculation = CalculationSettings(config: .default, settingsStore: InMemorySettingsStore())
        let (viewModel, _) = makeViewModel(
            at: PrayerTimeFixtures.instant(today, hour: 13),
            calculation: calculation
        )

        #expect(viewModel.config == .default)

        calculation.select(method: .karachi)

        #expect(viewModel.config.method == .karachi)
    }

    /// What Settings actually changes: the config handed to the use case on the next refresh.
    /// Home's view watches `config` and calls `refresh()`, so this is that pair, without a view.
    @Test func refreshingAfterAChangeAsksWithTheNewConfig() {
        let calculation = CalculationSettings(config: .default, settingsStore: InMemorySettingsStore())
        let repository = RecordingPrayerTimeRepository(schedules: [today: PrayerTimeFixtures.schedule(on: today)])
        let clock = TestClock(PrayerTimeFixtures.instant(today, hour: 13))
        let viewModel = HomeViewModel(
            useCase: GetPrayerScheduleUseCase(repository: repository, calendar: PrayerTimeFixtures.calendar),
            coordinates: .makkah,
            hijriDates: StubHijriDateService(),
            calculation: calculation,
            tips: SpyHomeTipReporter(),
            clock: clock
        )

        viewModel.refresh()
        #expect(repository.requestedConfigs.last == .default)

        calculation.select(method: .egyptian)
        calculation.select(madhab: .hanafi)
        viewModel.refresh()

        #expect(repository.requestedConfigs.last == CalculationConfig(method: .egyptian, madhab: .hanafi))
    }

    // MARK: Live location

    /// The whole point of the slice: a live fix that arrives after construction reaches the
    /// calculation, replacing the seeded point rather than sitting unused beside it.
    @Test(.timeLimit(.minutes(1)))
    func aLiveFixReplacesTheSeededCoordinates() async {
        let live = Coordinates(latitude: 51.5074, longitude: -0.1278)
        let location = MockLocationService(
            authorization: .authorized,
            coordinatesResult: .success(live)
        )
        let repository = RecordingPrayerTimeRepository(
            schedules: [today: PrayerTimeFixtures.schedule(on: today)]
        )
        let clock = TestClock(PrayerTimeFixtures.instant(today, hour: 13))
        let viewModel = HomeViewModel(
            useCase: GetPrayerScheduleUseCase(repository: repository, calendar: PrayerTimeFixtures.calendar),
            coordinates: .makkah,
            locationService: location,
            hijriDates: StubHijriDateService(),
            calculation: CalculationSettings(config: .default, settingsStore: InMemorySettingsStore()),
            tips: SpyHomeTipReporter(),
            clock: clock
        )

        let task = Task { await viewModel.start() }
        while repository.requestedCoordinates.last != live {
            await Task.yield()
        }
        task.cancel()
        await task.value

        // The very first ask is still the seeded point — the screen never sits on `.loading`
        // waiting for the fix — and the live one lands once it arrives.
        #expect(repository.requestedCoordinates.first == .makkah)
        #expect(repository.requestedCoordinates.last == live)
    }

    /// Home never asks for permission on its own — onboarding already did — so anything short
    /// of an already-authorized status leaves the seeded point untouched.
    @Test(.timeLimit(.minutes(1)))
    func withoutAuthorizationTheSeededCoordinatesStay() async {
        let location = MockLocationService(authorization: .denied)
        let repository = RecordingPrayerTimeRepository(
            schedules: [today: PrayerTimeFixtures.schedule(on: today)]
        )
        let clock = TestClock(PrayerTimeFixtures.instant(today, hour: 13))
        let viewModel = HomeViewModel(
            useCase: GetPrayerScheduleUseCase(repository: repository, calendar: PrayerTimeFixtures.calendar),
            coordinates: .makkah,
            locationService: location,
            hijriDates: StubHijriDateService(),
            calculation: CalculationSettings(config: .default, settingsStore: InMemorySettingsStore()),
            tips: SpyHomeTipReporter(),
            clock: clock
        )

        let task = Task { await viewModel.start() }
        while repository.requestedCoordinates.isEmpty {
            await Task.yield()
        }
        task.cancel()
        await task.value

        #expect(repository.requestedCoordinates.allSatisfy { $0 == .makkah })
        // Denied never reaches the read — the guard chain stops at the authorization check.
        #expect(location.coordinatesRequestCount == 0)
    }

    /// No `locationService` at all — every other test in this file — must behave exactly as it
    /// did before this slice: `start()` finishes without ever touching a service that isn't
    /// there.
    @Test(.timeLimit(.minutes(1)))
    func withNoLocationServiceTheSeededCoordinatesStay() async throws {
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 13))

        let task = Task { await viewModel.start() }
        while case .loading = viewModel.phase {
            await Task.yield()
        }
        task.cancel()
        await task.value

        #expect(try ready(viewModel).schedule.times.count == 6)
    }

    // MARK: Tip signals

    /// The input to the "opened a few times" rule. Donated once per appearance — the ticking
    /// loop must not inflate it.
    @Test(.timeLimit(.minutes(1)))
    func startingDonatesOneScreenOpening() async {
        let tips = SpyHomeTipReporter()
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 13), tips: tips)

        // `start()` ticks until cancelled, so it is driven as the view drives it: spawned, and
        // cancelled once the donation — which happens before the first sleep — has landed.
        let task = Task { await viewModel.start() }
        while tips.opens == 0 {
            await Task.yield()
        }
        task.cancel()
        await task.value

        #expect(tips.opens == 1)
    }

    @Test func refreshingReportsThatTheCountdownIsWithinToday() {
        let tips = SpyHomeTipReporter()
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 13), tips: tips)

        viewModel.refresh()

        #expect(tips.isCountingDownToTomorrow == false)
    }

    /// The other half of the tip's eligibility: it may only appear while the headline really
    /// is pointing at tomorrow.
    @Test func afterIshaTheRolloverIsReported() {
        let tips = SpyHomeTipReporter()
        let (viewModel, _) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 22), tips: tips)

        viewModel.refresh()

        #expect(tips.isCountingDownToTomorrow == true)
    }

    /// A day that could not be computed has no headline to explain, so the flag must come back
    /// down rather than keep a stale `true` from the last successful refresh.
    @Test func anUnavailableDayClearsTheRollover() {
        let tips = SpyHomeTipReporter()
        let (viewModel, _) = makeViewModel(
            at: PrayerTimeFixtures.instant(today, hour: 22),
            failure: .notComputable(today),
            tips: tips
        )

        viewModel.refresh()

        #expect(tips.isCountingDownToTomorrow == false)
    }

    // MARK: The heartbeat

    /// The countdown is driven by the clock's own stream rather than by a timer this type owns —
    /// which is what lets a test step a minute in microseconds instead of sleeping through one.
    @Test(.timeLimit(.minutes(1)))
    func theHeartbeatDrivesTheCountdownDown() async {
        let (viewModel, clock) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 15))

        let task = Task { await viewModel.start() }
        while !clock.isTicking {
            await Task.yield()
        }

        #expect(viewModel.countdown == 30 * 60)

        clock.tick(after: 60)
        while viewModel.countdown != 29 * 60 {
            await Task.yield()
        }

        task.cancel()
        await task.value
    }

    /// Cancelling the screen's task ends the stream, which is the whole reason the beat is an
    /// `AsyncStream` and not a `Timer`: there is nothing left running behind a screen nobody is
    /// looking at, and nothing anyone has to remember to invalidate.
    @Test(.timeLimit(.minutes(1)))
    func cancellingTheTaskStopsTheHeartbeat() async {
        let (viewModel, clock) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 15))

        let task = Task { await viewModel.start() }
        while !clock.isTicking {
            await Task.yield()
        }

        task.cancel()
        await task.value

        while clock.isTicking {
            await Task.yield()
        }

        #expect(clock.isTicking == false)
    }

    // MARK: Midnight

    /// The case a decrementing countdown cannot see. Between Isha and Fajr the countdown is
    /// perfectly healthy — it is counting towards a real prayer — but the six entries beneath it
    /// belong to a day that ended at midnight, so the tick has to recompute rather than subtract.
    @Test func crossingMidnightMovesOntoTheNewDaysSchedule() throws {
        let (viewModel, clock) = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 22))

        viewModel.refresh()
        #expect(try ready(viewModel).schedule.day == today)
        #expect(try ready(viewModel).upcoming.isTomorrow)

        clock.move(to: PrayerTimeFixtures.instant(today, hour: 24, minute: 1))
        viewModel.tick()

        let state = try ready(viewModel)
        #expect(state.schedule.day == tomorrow)
        #expect(state.currentPrayer == nil)
        #expect(state.upcoming.prayer == .fajr)
        // The same prayer it was counting towards a minute ago, but no longer "tomorrow's".
        #expect(state.upcoming.isTomorrow == false)
        #expect(viewModel.countdown == (4 * 3600) + (59 * 60))
    }

    // MARK: The city name

    /// The card is complete before the name arrives and complete again after it — the coordinates
    /// work offline, and only the name needs a network.
    @Test(.timeLimit(.minutes(1)))
    func aNameArrivesWithoutTheCardEverWaitingForIt() async throws {
        let places = StubPlaceNameResolver(name: "London")
        let (viewModel, _) = makeViewModel(
            at: PrayerTimeFixtures.instant(today, hour: 13),
            placeNames: places
        )

        let task = Task { await viewModel.start() }
        while viewModel.placeName == nil {
            await Task.yield()
        }
        task.cancel()
        await task.value

        #expect(viewModel.placeName == "London")
    }

    /// The non-blocking claim, tested rather than asserted: a lookup that has not come back yet
    /// leaves the countdown ticking. Before the resolution was moved beside the heartbeat instead
    /// of in front of it, this test hung.
    @Test(.timeLimit(.minutes(1)))
    func aSlowLookupDoesNotHoldUpTheCountdown() async {
        let places = StubPlaceNameResolver(name: "London", isSlow: true)
        let (viewModel, clock) = makeViewModel(
            at: PrayerTimeFixtures.instant(today, hour: 15),
            placeNames: places
        )

        let task = Task { await viewModel.start() }
        while !clock.isTicking {
            await Task.yield()
        }

        clock.tick(after: 60)
        while viewModel.countdown != 29 * 60 {
            await Task.yield()
        }

        // Still in flight, and the card has been counting down the whole time.
        #expect(viewModel.placeName == nil)

        task.cancel()
        await task.value
    }

    /// Offline, the card does not go looking. A request that can only fail is worse than no
    /// request: it is a system log, a delay, and the same empty answer.
    @Test(.timeLimit(.minutes(1)))
    func offlineTheCardNeverAsksForAName() async {
        let places = StubPlaceNameResolver(name: "London")
        let (viewModel, clock) = makeViewModel(
            at: PrayerTimeFixtures.instant(today, hour: 13),
            placeNames: places,
            reachability: StubReachability(isOnline: false)
        )

        // The heartbeat starts *after* the name would have been resolved, so waiting for it is
        // how this test knows the resolver has been passed by rather than merely not reached yet.
        let task = Task { await viewModel.start() }
        while !clock.isTicking {
            await Task.yield()
        }
        task.cancel()
        await task.value

        #expect(places.askCount == 0)
        #expect(viewModel.placeName == nil)
    }
}
