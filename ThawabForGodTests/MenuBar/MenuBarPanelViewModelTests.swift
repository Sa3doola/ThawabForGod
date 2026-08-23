//
//  MenuBarPanelViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The status item's title and the panel's contents.
///
/// The whole of the menu bar that a test can reach — `MenuBarController` is an `NSStatusItem` and
/// an `NSPopover` around this and holds no logic of its own, which is the reason the split exists.
///
/// Times are `PrayerTimeFixtures`': fajr 05:00, sunrise 06:30, dhuhr 12:00, asr 15:30,
/// maghrib 18:00, isha 19:30, all UTC.
@MainActor
struct MenuBarPanelViewModelTests {

    private let today = PrayerTimeFixtures.day(2026, 6, 15)
    private let tomorrow = PrayerTimeFixtures.day(2026, 6, 16)
    private let london = Coordinates(latitude: 51.5074, longitude: -0.1278)

    private func makeViewModel(
        store: InMemorySettingsStore,
        at now: Date
    ) -> MenuBarPanelViewModel {
        MenuBarPanelViewModel(
            timeline: NextPrayerTimeline(
                schedule: GetPrayerScheduleUseCase(
                    repository: PrayerTimeFixtures.repository(days: [today, tomorrow]),
                    calendar: PrayerTimeFixtures.calendar
                ),
                settingsStore: store,
                timeZone: .gmt
            ),
            l10n: LocalizationManager(
                settingsStore: store,
                numberFormatting: LocaleNumberFormattingService(),
                timeFormatting: LocaleTimeFormattingService(),
                language: .english
            ),
            now: now
        )
    }

    private func located() -> InMemorySettingsStore {
        InMemorySettingsStore(doubles: [
            .latitude: london.latitude,
            .longitude: london.longitude
        ])
    }

    // MARK: What the menu bar says

    /// The literals are written `7_200` as a `TimeInterval` rather than `2 * 60 * 60`, and that
    /// is not style: `#expect` decomposes the comparison, which loses the type context an
    /// integer literal needs to become a `Double`, and the two halves then never compare equal
    /// however right the value is.
    @Test func itNamesThePrayerBeingCountedDownTo() {
        let viewModel = makeViewModel(store: located(), at: PrayerTimeFixtures.instant(today, hour: 16))

        #expect(viewModel.upcoming?.prayer == .maghrib)
        #expect(viewModel.currentPrayer == .asr)
        #expect(viewModel.remaining == TimeInterval(7_200))
    }

    @Test func theTitleCarriesBothTheNameAndTheCountdown() throws {
        let viewModel = makeViewModel(store: located(), at: PrayerTimeFixtures.instant(today, hour: 16))
        let title = try #require(viewModel.statusTitle)

        #expect(title.contains("Maghrib"))
        // The digits themselves come from `LocalizationManager.countdownString`, which wraps them
        // in directional isolates — so the assertion is that the number is in there, not that the
        // string equals something a bidi mark would break.
        #expect(title.contains("2"))
    }

    @Test func thePanelListsTheWholeDay() {
        let viewModel = makeViewModel(store: located(), at: PrayerTimeFixtures.instant(today, hour: 16))

        #expect(viewModel.times.map(\.prayer) == [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha])
    }

    // MARK: The heartbeat

    /// A second inside the last hour, half a minute outside it. An idle Mac has no business being
    /// woken sixty times a minute to redraw a label reading `3h 30m`.
    @Test func itTicksBySecondsOnlyWhenSecondsAreVisible() {
        let far = makeViewModel(store: located(), at: PrayerTimeFixtures.instant(today, hour: 14))
        #expect(far.tickInterval == .seconds(30))

        let near = makeViewModel(store: located(), at: PrayerTimeFixtures.instant(today, hour: 17, minute: 30))
        #expect(near.tickInterval == .seconds(1))
    }

    /// A tick moves the clock and nothing else. Recomputing the solar arithmetic once a second to
    /// get the same answer sixty times a minute is the thing this avoids.
    @Test func aTickMovesTheCountdownWithoutRebuildingTheDay() {
        let viewModel = makeViewModel(store: located(), at: PrayerTimeFixtures.instant(today, hour: 16))
        let before = viewModel.snapshot

        viewModel.tick(PrayerTimeFixtures.instant(today, hour: 17))

        #expect(viewModel.remaining == TimeInterval(3_600))
        #expect(viewModel.snapshot == before)
    }

    /// Until the prayer actually arrives, at which point it must.
    @Test func crossingAPrayerRebuildsTheDay() {
        let viewModel = makeViewModel(store: located(), at: PrayerTimeFixtures.instant(today, hour: 16))

        viewModel.tick(PrayerTimeFixtures.instant(today, hour: 18))

        #expect(viewModel.upcoming?.prayer == .isha)
        #expect(viewModel.currentPrayer == .maghrib)
    }

    @Test func afterIshaItCountsDownToTomorrowsFajr() {
        let viewModel = makeViewModel(store: located(), at: PrayerTimeFixtures.instant(today, hour: 16))

        viewModel.tick(PrayerTimeFixtures.instant(today, hour: 20))

        #expect(viewModel.upcoming?.prayer == .fajr)
        #expect(viewModel.upcoming?.isTomorrow == true)
    }

    /// A countdown never runs past zero into a negative, which would render as a minus sign in
    /// the menu bar during the moment before the next tick lands.
    @Test func theCountdownFloorsAtZero() {
        let viewModel = makeViewModel(store: located(), at: PrayerTimeFixtures.instant(today, hour: 16))

        viewModel.tick(PrayerTimeFixtures.instant(today, hour: 18, minute: 0))

        #expect((viewModel.remaining ?? -1) >= TimeInterval(0))
    }

    // MARK: With no position

    /// The same answer the widget gives, from the same timeline — which is the point of sharing
    /// it. A menu bar quietly counting down to Makkah's Maghrib in London is the failure both are
    /// shaped to avoid.
    @Test func withNoPositionThereIsNothingToCountDownTo() {
        let viewModel = makeViewModel(store: InMemorySettingsStore(), at: PrayerTimeFixtures.instant(today, hour: 16))

        #expect(viewModel.statusTitle == nil)
        #expect(viewModel.remaining == nil)
        #expect(viewModel.times.isEmpty)
        #expect(viewModel.noticeKey == .widgetNoLocation)
        #expect(viewModel.statusSymbol == "location.slash")
    }

    /// And it does not spin: with nothing to count down to, a tick must not rebuild the timeline
    /// on a one-second beat over an answer that cannot have changed.
    @Test func withNoPositionATickChangesNothingButTheClock() {
        let viewModel = makeViewModel(store: InMemorySettingsStore(), at: PrayerTimeFixtures.instant(today, hour: 16))
        let before = viewModel.snapshot

        viewModel.tick(PrayerTimeFixtures.instant(today, hour: 17))

        #expect(viewModel.snapshot == before)
        #expect(viewModel.now == PrayerTimeFixtures.instant(today, hour: 17))
    }
}
