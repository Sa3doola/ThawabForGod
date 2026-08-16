//
//  GetPrayerScheduleUseCaseTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The use case's job is next-prayer resolution, so that is what these exercise: the three
/// positions on the timeline, and the awkward hours after Isha where the answer belongs to
/// the following day.
struct GetPrayerScheduleUseCaseTests {

    private let today = PrayerTimeFixtures.day(2026, 6, 15)
    private let tomorrow = PrayerTimeFixtures.day(2026, 6, 16)
    private let coordinates = Coordinates.makkah

    private func makeUseCase(days: [Date]) -> GetPrayerScheduleUseCase {
        GetPrayerScheduleUseCase(
            repository: PrayerTimeFixtures.repository(days: days),
            calendar: PrayerTimeFixtures.calendar
        )
    }

    private func upcoming(at now: Date, days: [Date]) throws -> UpcomingPrayer {
        try makeUseCase(days: days).upcomingPrayer(for: coordinates, at: now, config: .default)
    }

    // MARK: Next prayer

    @Test func beforeFajrTheNextPrayerIsTodaysFajr() throws {
        let result = try upcoming(at: PrayerTimeFixtures.instant(today, hour: 3), days: [today])

        #expect(result.prayer == .fajr)
        #expect(result.isTomorrow == false)
        #expect(result.date == PrayerTimeFixtures.instant(today, hour: 5))
    }

    @Test func betweenTwoPrayersTheNextIsTheLaterOfThePair() throws {
        let result = try upcoming(at: PrayerTimeFixtures.instant(today, hour: 13), days: [today])

        #expect(result.prayer == .asr)
        #expect(result.isTomorrow == false)
        #expect(result.date == PrayerTimeFixtures.instant(today, hour: 15, minute: 30))
    }

    /// Sunrise sits on the timeline between Fajr and Dhuhr, so it is a legitimate answer —
    /// this pins that decision rather than leaving it to chance.
    @Test func sunriseCanBeTheNextMarker() throws {
        let result = try upcoming(at: PrayerTimeFixtures.instant(today, hour: 6), days: [today])

        #expect(result.prayer == .sunrise)
    }

    /// Exactly on a prayer time, that prayer has begun — the countdown moves to the one after.
    @Test func atAPrayerTimeTheNextIsTheFollowingPrayer() throws {
        let result = try upcoming(at: PrayerTimeFixtures.instant(today, hour: 12), days: [today])

        #expect(result.prayer == .asr)
    }

    @Test func afterIshaTheNextPrayerIsTomorrowsFajr() throws {
        let result = try upcoming(
            at: PrayerTimeFixtures.instant(today, hour: 22),
            days: [today, tomorrow]
        )

        #expect(result.prayer == .fajr)
        #expect(result.isTomorrow)
        #expect(result.date == PrayerTimeFixtures.instant(tomorrow, hour: 5))
    }

    /// The boundary itself: Isha has begun, so it is no longer upcoming.
    @Test func atIshaTheNextPrayerAlreadyRollsOver() throws {
        let result = try upcoming(
            at: PrayerTimeFixtures.instant(today, hour: 19, minute: 30),
            days: [today, tomorrow]
        )

        #expect(result.prayer == .fajr)
        #expect(result.isTomorrow)
    }

    @Test func afterIshaWithNoFollowingDayTheErrorSurfaces() {
        #expect(throws: PrayerTimeError.self) {
            try upcoming(at: PrayerTimeFixtures.instant(today, hour: 22), days: [today])
        }
    }

    @Test func repositoryFailuresPropagate() {
        let repository = StubPrayerTimeRepository(failure: .notComputable(today))
        let useCase = GetPrayerScheduleUseCase(
            repository: repository,
            calendar: PrayerTimeFixtures.calendar
        )

        #expect(throws: PrayerTimeError.self) {
            try useCase.upcomingPrayer(for: coordinates, at: today, config: .default)
        }
    }

    // MARK: Schedule passthrough

    @Test func scheduleReturnsTheDaysSixMarkersInOrder() throws {
        let schedule = try makeUseCase(days: [today])
            .schedule(for: coordinates, date: today, config: .default)

        #expect(schedule.times.map(\.prayer) == Prayer.allCases)
        #expect(schedule.times.map(\.date) == schedule.times.map(\.date).sorted())
    }
}

/// `PrayerSchedule` answers "current" and "next" within its own day and refuses to guess
/// beyond it. These pin both halves, including the deliberate `nil`s.
struct PrayerScheduleTests {

    private let today = PrayerTimeFixtures.day(2026, 6, 15)

    @Test func currentPrayerIsNilBeforeFajr() {
        let schedule = PrayerTimeFixtures.schedule(on: today)

        #expect(schedule.currentPrayer(at: PrayerTimeFixtures.instant(today, hour: 3)) == nil)
    }

    @Test func currentPrayerIsTheMostRecentMarker() {
        let schedule = PrayerTimeFixtures.schedule(on: today)

        #expect(schedule.currentPrayer(at: PrayerTimeFixtures.instant(today, hour: 13)) == .dhuhr)
        #expect(schedule.currentPrayer(at: PrayerTimeFixtures.instant(today, hour: 22)) == .isha)
    }

    @Test func currentPrayerIncludesTheExactBoundary() {
        let schedule = PrayerTimeFixtures.schedule(on: today)

        #expect(schedule.currentPrayer(at: PrayerTimeFixtures.instant(today, hour: 12)) == .dhuhr)
    }

    @Test func nextPrayerIsNilAfterIsha() {
        let schedule = PrayerTimeFixtures.schedule(on: today)

        #expect(schedule.nextPrayer(at: PrayerTimeFixtures.instant(today, hour: 22)) == nil)
    }

    @Test func timesAreSortedEvenWhenBuiltOutOfOrder() {
        let schedule = PrayerSchedule(
            day: today,
            times: [
                PrayerTime(prayer: .isha, date: PrayerTimeFixtures.instant(today, hour: 19)),
                PrayerTime(prayer: .fajr, date: PrayerTimeFixtures.instant(today, hour: 5))
            ]
        )

        #expect(schedule.times.map(\.prayer) == [.fajr, .isha])
    }
}
