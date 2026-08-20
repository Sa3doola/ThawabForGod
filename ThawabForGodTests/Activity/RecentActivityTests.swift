//
//  RecentActivityTests.swift
//  ThawabForGodTests
//

import Foundation
import SwiftData
import Testing
@testable import ThawabForGod

/// The value itself: what it encodes, what it can be read back as, and where it goes.
struct RecentActivityTests {

    private let when = Date(timeIntervalSince1970: 1_000_000)

    // MARK: The Quran

    @Test func aVerseRoundTripsThroughItsSubject() {
        let reference = VerseReference(surah: 2, verse: 142)
        let activity = RecentActivity.quran(reference, of: 286, at: when)

        #expect(activity.kind == .quran)
        #expect(activity.verseReference == reference)
        #expect(activity.route == .quranVerse(reference))
        #expect(activity.fraction == 142.0 / 286.0)
    }

    /// The subject is a string, and a corrupted one has to have somewhere sensible to land.
    @Test func anUnreadableSubjectHasNoReferenceAndNoRoute() {
        let activity = RecentActivity(
            kind: .quran,
            subject: "not-a-verse",
            progressValue: 1,
            progressTotal: 1,
            occurredAt: when
        )

        #expect(activity.verseReference == nil)
        #expect(activity.route == nil)
    }

    // MARK: The adhkar

    @Test func acategoryRoundTripsThroughItsSubject() {
        let activity = RecentActivity.adhkar(.morning, completed: 7, of: 28, at: when)

        #expect(activity.adhkarCategory == .morning)
        #expect(activity.route == .adhkar(.morning))
        #expect(activity.fraction == 0.25)
    }

    @Test func acategoryThisBuildNoLongerHasIsNotRouted() {
        let activity = RecentActivity(
            kind: .adhkar,
            subject: "after_prayer",
            progressValue: 1,
            progressTotal: 3,
            occurredAt: when
        )

        #expect(activity.adhkarCategory == nil)
        #expect(activity.route == nil)
    }

    // MARK: The tasbih

    @Test func adhikrRoundTripsThroughItsSubject() {
        let activity = RecentActivity.tasbih(dhikrID: "subhanallah", count: 33, of: 33, at: when)

        #expect(activity.tasbihDhikrID == "subhanallah")
        #expect(activity.route == .tasbih)
        #expect(activity.fraction == 1)
    }

    // MARK: The bar

    @Test func aTotalOfZeroDrawsNoBarRatherThanDividing() {
        let activity = RecentActivity(
            kind: .tasbih,
            subject: "x",
            progressValue: 5,
            progressTotal: 0,
            occurredAt: when
        )

        #expect(activity.fraction == nil)
    }

    /// A corpus rebuild could shorten a chapter under a stored position, and a bar drawn past its
    /// end is a worse way to find that out than a full one.
    @Test func aValuePastItsTotalFillsTheBarRatherThanOverflowingIt() {
        let activity = RecentActivity.quran(
            VerseReference(surah: 1, verse: 20),
            of: 7,
            at: when
        )

        #expect(activity.fraction == 1)
    }

    /// The identity that makes the store hold one row per kind.
    @Test func theKindIsTheIdentity() {
        #expect(RecentActivity.tasbih(dhikrID: "a", count: 1, of: 2, at: when).id == .tasbih)
        #expect(RecentActivity.adhkar(.evening, completed: 1, of: 2, at: when).id == .adhkar)
    }
}

/// Against a real in-memory SwiftData store, because what is under test here *is* the storage:
/// the one-row-per-kind rule, and what happens to a row whose kind this build no longer has.
struct RecentActivityRepositoryTests {

    private func makeRepository() throws -> RecentActivityRepository {
        let persistence = try PersistenceController(inMemory: true)
        return RecentActivityRepository(modelContainer: persistence.container)
    }

    private let earlier = Date(timeIntervalSince1970: 1_000_000)
    private let later = Date(timeIntervalSince1970: 2_000_000)

    @Test func startsWithNothing() async throws {
        let repository = try makeRepository()

        #expect(try await repository.recent().isEmpty)
    }

    @Test func recordsAndReadsBack() async throws {
        let repository = try makeRepository()
        let activity = RecentActivity.tasbih(dhikrID: "subhanallah", count: 12, of: 33, at: earlier)

        try await repository.record(activity)

        #expect(try await repository.recent() == [activity])
    }

    /// The contract the whole section rests on: recording again *replaces*, so a sitting with a
    /// hundred taps leaves one row rather than a hundred.
    @Test func recordingTheSameKindAgainReplacesIt() async throws {
        let repository = try makeRepository()

        try await repository.record(.tasbih(dhikrID: "subhanallah", count: 1, of: 33, at: earlier))
        try await repository.record(.tasbih(dhikrID: "alhamdulillah", count: 30, of: 33, at: later))

        let recent = try await repository.recent()

        #expect(recent.count == 1)
        #expect(recent.first?.tasbihDhikrID == "alhamdulillah")
        #expect(recent.first?.progressValue == 30)
        #expect(recent.first?.occurredAt == later)
    }

    @Test func theThreeKindsCoexist() async throws {
        let repository = try makeRepository()

        try await repository.record(.tasbih(dhikrID: "subhanallah", count: 1, of: 33, at: earlier))
        try await repository.record(.adhkar(.morning, completed: 2, of: 28, at: later))
        try await repository.record(
            .quran(VerseReference(surah: 2, verse: 142), of: 286, at: earlier)
        )

        let recent = try await repository.recent()

        #expect(recent.count == 3)
        // Most recent first, which is the order the row is drawn in.
        #expect(recent.first?.kind == .adhkar)
    }

    /// A row written by a later build, read by an earlier one: dropped, and the other two still
    /// come back — the same forward-compatibility rule `HomeLayout` follows.
    @Test func aRowWhoseKindIsUnknownIsDroppedRatherThanFailingTheFetch() async throws {
        let persistence = try PersistenceController(inMemory: true)
        let repository = RecentActivityRepository(modelContainer: persistence.container)

        try await repository.record(.adhkar(.morning, completed: 2, of: 28, at: earlier))

        let context = ModelContext(persistence.container)
        context.insert(
            RecentActivityRecord(
                kindRaw: "memorization",
                subject: "x",
                progressValue: 1,
                progressTotal: 2,
                occurredAt: later
            )
        )
        try context.save()

        let recent = try await repository.recent()

        #expect(recent.map(\.kind) == [.adhkar])
    }
}
