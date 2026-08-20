//
//  PrayerTrackerTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The value: what can be marked, and what cannot.
struct PrayerRecordTests {

    private let day = PrayerTimeFixtures.day(2026, 6, 15)

    @Test func onlyTheFiveObligatoryPrayersAreTrackable() {
        #expect(PrayerRecord.trackable == [.fajr, .dhuhr, .asr, .maghrib, .isha])
        #expect(PrayerRecord.trackable.contains(.sunrise) == false)
    }

    /// Sunrise ends Fajr's window rather than starting a prayer, so marking it must not be able
    /// to make "5 of 5" reachable at four of five.
    @Test func sunriseCannotBeMarked() {
        let record = PrayerRecord(day: day).setting(.sunrise, to: true)

        #expect(record.completed.isEmpty)
        #expect(record.completedCount == 0)
    }

    /// The same filter on the way in, for a row written by a build that tracked it.
    @Test func aStoredSunriseIsDroppedOnConstruction() {
        let record = PrayerRecord(day: day, completed: [.fajr, .sunrise])

        #expect(record.completed == [.fajr])
    }

    @Test func markingAndUnmarkingAreStatedRatherThanToggled() {
        var record = PrayerRecord(day: day)

        record = record.setting(.fajr, to: true)
        record = record.setting(.fajr, to: true)

        #expect(record.completed == [.fajr])

        record = record.setting(.fajr, to: false)

        #expect(record.completed.isEmpty)
    }

    @Test func aDayIsCompleteAtFive() {
        var record = PrayerRecord(day: day)
        #expect(record.isComplete == false)

        for prayer in PrayerRecord.trackable {
            record = record.setting(prayer, to: true)
        }

        #expect(record.isComplete)
        #expect(record.completedCount == 5)
    }
}

/// The store and the streak, against a real in-memory SwiftData container.
struct PrayerTrackerRepositoryTests {

    private let calendar = PrayerTimeFixtures.calendar
    private let today = PrayerTimeFixtures.day(2026, 6, 15)

    private func makeUseCase() throws -> (PrayerTrackerUseCase, PrayerTrackerRepository) {
        let persistence = try PersistenceController(inMemory: true)
        let repository = PrayerTrackerRepository(modelContainer: persistence.container)
        return (PrayerTrackerUseCase(repository: repository, calendar: calendar), repository)
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today)!
    }

    private func complete(_ useCase: PrayerTrackerUseCase, on date: Date) async throws {
        for prayer in PrayerRecord.trackable {
            try await useCase.setCompleted(true, of: prayer, on: date)
        }
    }

    // MARK: The store

    /// A day nobody has marked anything on is not a missing day — it is a day with nothing
    /// marked, and callers should not have to tell those apart.
    @Test func anUnmarkedDayReadsAsAnEmptyRecord() async throws {
        let (useCase, _) = try makeUseCase()

        let record = try await useCase.record(on: today)

        #expect(record.completed.isEmpty)
        #expect(record.day == today)
    }

    @Test func aMarkedPrayerComesBack() async throws {
        let (useCase, _) = try makeUseCase()

        try await useCase.setCompleted(true, of: .asr, on: today)

        #expect(try await useCase.record(on: today).completed == [.asr])
    }

    /// Any instant in a day is that day: the time of the tap must not create a second row.
    @Test func anyInstantInADayIsTheSameDay() async throws {
        let (useCase, _) = try makeUseCase()

        try await useCase.setCompleted(true, of: .fajr, on: PrayerTimeFixtures.instant(today, hour: 5))
        try await useCase.setCompleted(true, of: .isha, on: PrayerTimeFixtures.instant(today, hour: 21))

        #expect(try await useCase.record(on: today).completed == [.fajr, .isha])
    }

    /// An empty row is indistinguishable from no row, and keeping it would grow the store by a
    /// row for every day somebody tapped a circle and tapped it again.
    @Test func unmarkingTheLastPrayerRemovesTheRow() async throws {
        let (useCase, repository) = try makeUseCase()

        try await useCase.setCompleted(true, of: .asr, on: today)
        try await useCase.setCompleted(false, of: .asr, on: today)

        #expect(try await repository.records(from: day(-1), to: day(1)).isEmpty)
    }

    // MARK: The streak

    @Test func nothingMarkedIsNoStreak() async throws {
        let (useCase, _) = try makeUseCase()

        #expect(try await useCase.streak(endingOn: today) == 0)
    }

    @Test func aRunOfCompleteDaysCounts() async throws {
        let (useCase, _) = try makeUseCase()

        for offset in -2...0 {
            try await complete(useCase, on: day(offset))
        }

        #expect(try await useCase.streak(endingOn: today) == 3)
    }

    /// The rule that makes the number usable: it is the middle of the day for somebody, and
    /// zeroing the run at Fajr every morning would make it meaningless.
    @Test func todayBeingUnfinishedDoesNotBreakTheRun() async throws {
        let (useCase, _) = try makeUseCase()

        try await complete(useCase, on: day(-2))
        try await complete(useCase, on: day(-1))
        try await useCase.setCompleted(true, of: .fajr, on: today)

        #expect(try await useCase.streak(endingOn: today) == 2)
    }

    @Test func aMissedDayBreaksTheRun() async throws {
        let (useCase, _) = try makeUseCase()

        try await complete(useCase, on: day(-3))
        // day(-2) missed
        try await complete(useCase, on: day(-1))
        try await complete(useCase, on: today)

        #expect(try await useCase.streak(endingOn: today) == 2)
    }

    /// A day with four of five is not a day in the run.
    @Test func anIncompleteDayDoesNotCount() async throws {
        let (useCase, _) = try makeUseCase()

        try await complete(useCase, on: day(-1))
        for prayer in PrayerRecord.trackable.dropLast() {
            try await useCase.setCompleted(true, of: prayer, on: day(-2))
        }

        #expect(try await useCase.streak(endingOn: today) == 1)
    }
}
