//
//  TasbihProgressRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The SwiftData side, against a real in-memory container.
///
/// Worth doing for real rather than against a stub: `@ModelActor`, the `#Predicate` on `dhikrID`
/// and the unique constraint are all things that compile happily and fail at runtime, and the
/// upsert is the one piece of behaviour a counter depends on to not accumulate a row per lap.
struct TasbihProgressRepositoryTests {

    private func makeRepository() throws -> TasbihProgressRepository {
        let persistence = try PersistenceController(inMemory: true)
        return TasbihProgressRepository(modelContainer: persistence.container)
    }

    @Test func anUncountedPresetHasNoSession() async throws {
        let repository = try makeRepository()

        #expect(try await repository.session(for: "subhanallah") == nil)
    }

    @Test func aSavedSessionReadsBackWhole() async throws {
        let repository = try makeRepository()
        let session = TasbihSession(
            dhikrID: "subhanallah",
            currentCount: 12,
            targetCount: 33,
            completedLaps: 4,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try await repository.save(session)

        #expect(try await repository.session(for: "subhanallah") == session)
    }

    /// The behaviour a counter leans on: saving the same dhikr repeatedly updates one row rather
    /// than piling up a row per checkpoint — and the row keeps its identity through it.
    @Test func savingTheSamePresetAgainUpdatesInPlace() async throws {
        let repository = try makeRepository()
        let first = TasbihSession(dhikrID: "subhanallah", currentCount: 5, targetCount: 33)

        try await repository.save(first)
        var second = first
        second.currentCount = 19
        second.completedLaps = 1
        try await repository.save(second)

        let stored = try #require(await repository.session(for: "subhanallah"))
        #expect(stored.currentCount == 19)
        #expect(stored.completedLaps == 1)
        #expect(stored.id == first.id, "the stored row must keep its identity across a save")
    }

    @Test func differentPresetsAreKeptApart() async throws {
        let repository = try makeRepository()
        let subhan = TasbihSession(dhikrID: "subhanallah", currentCount: 5, targetCount: 33)
        let hamd = TasbihSession(dhikrID: "alhamdulillah", currentCount: 9, targetCount: 33)

        try await repository.save(subhan)
        try await repository.save(hamd)

        #expect(try await repository.session(for: "subhanallah")?.currentCount == 5)
        #expect(try await repository.session(for: "alhamdulillah")?.currentCount == 9)
    }

    @Test func resettingClearsTheSession() async throws {
        let repository = try makeRepository()
        try await repository.save(
            TasbihSession(dhikrID: "subhanallah", currentCount: 30, targetCount: 33)
        )

        try await repository.reset(dhikrID: "subhanallah")

        #expect(try await repository.session(for: "subhanallah") == nil)
    }

    @Test func resettingSomethingUncountedIsHarmless() async throws {
        let repository = try makeRepository()

        try await repository.reset(dhikrID: "never-counted")

        #expect(try await repository.session(for: "never-counted") == nil)
    }

    @Test func resettingOnePresetLeavesTheOthersAlone() async throws {
        let repository = try makeRepository()
        try await repository.save(TasbihSession(dhikrID: "subhanallah", targetCount: 33))
        try await repository.save(
            TasbihSession(dhikrID: "alhamdulillah", currentCount: 9, targetCount: 33)
        )

        try await repository.reset(dhikrID: "subhanallah")

        #expect(try await repository.session(for: "subhanallah") == nil)
        #expect(try await repository.session(for: "alhamdulillah")?.currentCount == 9)
    }

    /// Proves the write reaches the store, not just this actor's own context — which is what
    /// makes a count survive the app being killed and relaunched.
    @Test func writesFromTheModelActorSurviveANewContext() async throws {
        let persistence = try PersistenceController(inMemory: true)
        let repository = TasbihProgressRepository(modelContainer: persistence.container)
        let session = TasbihSession(dhikrID: "astaghfirullah", currentCount: 61, targetCount: 100)

        try await repository.save(session)

        let second = TasbihProgressRepository(modelContainer: persistence.container)
        #expect(try await second.session(for: "astaghfirullah") == session)
    }
}
