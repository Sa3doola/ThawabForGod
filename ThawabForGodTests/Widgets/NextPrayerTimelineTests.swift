//
//  NextPrayerTimelineTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The timeline a widget is drawn from.
///
/// It is testable at all because none of it imports WidgetKit: `NextPrayerTimeline` produces
/// plain values and the extension conforms them to `TimelineEntry` in one line. That split is
/// the reason this suite can run in the app's test target, which cannot see an extension.
///
/// Times come from `PrayerTimeFixtures` — fajr 05:00, sunrise 06:30, dhuhr 12:00, asr 15:30,
/// maghrib 18:00, isha 19:30, all UTC — so what is under test is the entry-building rather than
/// astronomy.
struct NextPrayerTimelineTests {

    private let today = PrayerTimeFixtures.day(2026, 6, 15)
    private let tomorrow = PrayerTimeFixtures.day(2026, 6, 16)
    private let london = Coordinates(latitude: 51.5074, longitude: -0.1278)

    private func makeTimeline(
        store: InMemorySettingsStore,
        repository: StubPrayerTimeRepository? = nil
    ) -> NextPrayerTimeline {
        NextPrayerTimeline(
            schedule: GetPrayerScheduleUseCase(
                repository: repository ?? PrayerTimeFixtures.repository(days: [today, tomorrow]),
                calendar: PrayerTimeFixtures.calendar
            ),
            settingsStore: store,
            timeZone: .gmt
        )
    }

    private func storeWithLocation() -> InMemorySettingsStore {
        InMemorySettingsStore(doubles: [
            .latitude: london.latitude,
            .longitude: london.longitude
        ])
    }

    // MARK: One entry per transition

    /// Not one per minute. The countdown on screen animates itself, so the only moments the
    /// content changes are the moments a prayer arrives — and waking an extension sixty times an
    /// hour is how a widget gets its refresh budget taken away.
    @Test func thereIsOneEntryPerRemainingPrayer() {
        let timeline = makeTimeline(store: storeWithLocation())
        let now = PrayerTimeFixtures.instant(today, hour: 4)

        let entries = timeline.entries(from: now)

        // `now`, then all six of today's markers.
        #expect(entries.count == 7)
        #expect(entries.first?.date == now)
        #expect(entries.map(\.date) == [now] + PrayerTimeFixtures.schedule(on: today).times.map(\.date))
    }

    @Test func entriesStartAtNowAndOnlyLookForward() {
        let timeline = makeTimeline(store: storeWithLocation())
        let afternoon = PrayerTimeFixtures.instant(today, hour: 16)

        let entries = timeline.entries(from: afternoon)

        #expect(entries.first?.date == afternoon)
        // Maghrib and isha remain; the four markers already past do not.
        #expect(entries.count == 3)
        let stale = entries.filter { $0.date < afternoon }
        #expect(stale.isEmpty)
    }

    @Test func eachEntryNamesThePrayerItIsCountingDownTo() {
        let timeline = makeTimeline(store: storeWithLocation())

        let entries = timeline.entries(from: PrayerTimeFixtures.instant(today, hour: 4))
        let upcoming = entries.compactMap { entry -> Prayer? in
            guard case .schedule(let day) = entry.content else { return nil }
            return day.upcoming.prayer
        }

        #expect(upcoming == [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha, .fajr])
    }

    // MARK: After Isha

    /// The roll-over `GetPrayerScheduleUseCase` already owns, seen from the widget's side.
    @Test func afterIshaTheCountdownPointsAtTomorrowsFajr() throws {
        let timeline = makeTimeline(store: storeWithLocation())

        let entries = timeline.entries(from: PrayerTimeFixtures.instant(today, hour: 20))
        let last = try #require(entries.last)

        guard case .schedule(let day) = last.content else {
            Issue.record("expected a schedule")
            return
        }

        #expect(day.upcoming.prayer == .fajr)
        #expect(day.upcoming.isTomorrow)
        #expect(day.upcoming.date == PrayerTimeFixtures.instant(tomorrow, hour: 5))
    }

    /// And the list beside it turns over with it. Showing today's six times under a countdown to
    /// a seventh that is not among them would be six rows in the past and one answer that does
    /// not match any of them.
    @Test func theListTurnsOverWithTheCountdown() {
        let timeline = makeTimeline(store: storeWithLocation())

        let entries = timeline.entries(from: PrayerTimeFixtures.instant(today, hour: 20))

        guard case .schedule(let day) = entries.last?.content else {
            Issue.record("expected a schedule")
            return
        }

        #expect(day.times.first?.date == PrayerTimeFixtures.instant(tomorrow, hour: 5))
        // And nothing is marked current, because the moment shown is not inside that day.
        #expect(day.current == nil)
    }

    @Test func theCurrentPrayerIsMarkedWithinTheDay() {
        let timeline = makeTimeline(store: storeWithLocation())

        let entries = timeline.entries(from: PrayerTimeFixtures.instant(today, hour: 16))

        guard case .schedule(let day) = entries.first?.content else {
            Issue.record("expected a schedule")
            return
        }

        #expect(day.current == .asr)
    }

    // MARK: When there is no answer

    /// The decision the whole slice turns on. Home may draw Makkah as a placeholder because the
    /// reader can see where it thinks they are; a Home Screen widget is glanced at, believed,
    /// and wrong all day.
    @Test func withNoPositionItSaysSoRatherThanGuessingMakkah() {
        let timeline = makeTimeline(store: InMemorySettingsStore())

        let entries = timeline.entries(from: PrayerTimeFixtures.instant(today, hour: 10))

        #expect(entries.count == 1)
        #expect(entries.first?.content == .noLocation)
    }

    /// The cache counts as a position, which is the point of having it: a reader who has moved
    /// gets the widget for where they are rather than where onboarding was told.
    @Test func theCachedPositionIsEnoughOnItsOwn() {
        let store = InMemorySettingsStore()
        store.recordLastKnown(london)

        let entries = makeTimeline(store: store).entries(from: PrayerTimeFixtures.instant(today, hour: 10))

        #expect(entries.first?.content != .noLocation)
    }

    /// A latitude the arithmetic cannot answer for. An empty timeline would be a blank rectangle
    /// on somebody's Home Screen with no way to find out why.
    @Test func anUncomputableDayIsSaidRatherThanLeftBlank() {
        var repository = PrayerTimeFixtures.repository(days: [today, tomorrow])
        repository.failure = .notComputable(today)

        let timeline = makeTimeline(store: storeWithLocation(), repository: repository)
        let entries = timeline.entries(from: PrayerTimeFixtures.instant(today, hour: 10))

        #expect(entries.count == 1)
        #expect(entries.first?.content == .notComputable)
    }

    @Test func aTimelineIsNeverEmpty() {
        let cases: [InMemorySettingsStore] = [InMemorySettingsStore(), storeWithLocation()]

        for store in cases {
            #expect(!makeTimeline(store: store).entries(from: PrayerTimeFixtures.instant(today, hour: 10)).isEmpty)
        }
    }

    // MARK: Coming back

    /// Once a day, at the dawn the last entry was counting down to — not on a fixed interval.
    @Test func itAsksToBeReloadedWhenTheLastCountdownRunsOut() {
        let timeline = makeTimeline(store: storeWithLocation())
        let now = PrayerTimeFixtures.instant(today, hour: 20)
        let entries = timeline.entries(from: now)

        #expect(timeline.reloadDate(after: entries, from: now) == PrayerTimeFixtures.instant(tomorrow, hour: 5))
    }

    /// A widget with no position retries rather than giving up — the reader may be finishing
    /// onboarding right now, and nothing else would come along to reload it.
    @Test func aWidgetWithNothingToShowTriesAgainShortly() {
        let timeline = makeTimeline(store: InMemorySettingsStore())
        let now = PrayerTimeFixtures.instant(today, hour: 10)
        let entries = timeline.entries(from: now)

        #expect(timeline.reloadDate(after: entries, from: now) == now.addingTimeInterval(3_600))
    }

    // MARK: Presentation

    @Test func theStyleIsReadFromTheSharedSettings() throws {
        let store = storeWithLocation()
        store.set(NumberSystem.arabicIndic.rawValue, for: .numberSystem)
        store.set(ClockFormat.twentyFourHour.rawValue, for: .clockFormat)
        store.set(AccentPalette.emerald.rawValue, for: .accentPalette)

        let entries = makeTimeline(store: store).entries(from: PrayerTimeFixtures.instant(today, hour: 10))
        let style = try #require(entries.first?.style)

        #expect(style.numberSystem == .arabicIndic)
        #expect(style.clockFormat == .twentyFourHour)
        #expect(style.accent == .emerald)
    }

    /// An unset preference means the user has never chosen, so the device decides — the same
    /// fallback `ThemeManager` and `LocalizationManager` make, repeated here because a widget
    /// has neither of them.
    @Test func anUnsetPreferenceFallsBackRatherThanTrapping() throws {
        let store = storeWithLocation()
        store.set("not-a-palette", for: .accentPalette)

        let entries = makeTimeline(store: store).entries(from: PrayerTimeFixtures.instant(today, hour: 10))
        let style = try #require(entries.first?.style)

        #expect(style.accent == .fallback)
        #expect(style.clockFormat == .fallback)
    }
}
