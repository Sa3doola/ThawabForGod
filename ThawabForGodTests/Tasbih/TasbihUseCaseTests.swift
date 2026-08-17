//
//  TasbihUseCaseTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The lap arithmetic, exhaustively — this is the part of the feature that would be wrong in a
/// way nobody notices until they have counted to 33 and the tally says 1 of 33 with no lap
/// recorded.
struct TasbihCountingTests {

    private let dhikr = TasbihDhikr.stub(targetCount: 33)

    private func counting(_ session: TasbihSession, times: Int) -> TasbihSession {
        var session = session
        for _ in 0..<times {
            session = TasbihUseCase.counting(session).session
        }
        return session
    }

    // MARK: Within a lap

    @Test func oneRecitationMovesTheCountAndNothingElse() {
        let outcome = TasbihUseCase.counting(TasbihSession.starting(dhikr))

        #expect(outcome.session.currentCount == 1)
        #expect(outcome.session.completedLaps == 0)
        #expect(outcome.completedLap == false)
    }

    @Test func theCountRisesToOneShortOfTheTargetWithoutCompletingALap() {
        let session = counting(TasbihSession.starting(dhikr), times: 32)

        #expect(session.currentCount == 32)
        #expect(session.completedLaps == 0)
    }

    // MARK: The lap boundary

    /// The case the whole type exists for: the 33rd recitation of a 33-lap finishes it, and the
    /// count returns to zero rather than sitting on 33.
    @Test func theRecitationThatReachesTheTargetCompletesALapAndWraps() {
        let session = counting(TasbihSession.starting(dhikr), times: 32)

        let outcome = TasbihUseCase.counting(session)

        #expect(outcome.completedLap)
        #expect(outcome.session.currentCount == 0)
        #expect(outcome.session.completedLaps == 1)
    }

    @Test func lapsAccumulateOverSeveralRounds() {
        let session = counting(TasbihSession.starting(dhikr), times: 33 * 3)

        #expect(session.completedLaps == 3)
        #expect(session.currentCount == 0)
    }

    @Test func countingOnPastALapStartsTheNextOne() {
        let session = counting(TasbihSession.starting(dhikr), times: 35)

        #expect(session.completedLaps == 1)
        #expect(session.currentCount == 2)
    }

    /// A target of one completes a lap on every single recitation — the degenerate case, and the
    /// one an `==` comparison and an off-by-one would both get wrong.
    @Test func aTargetOfOneCompletesALapEveryTime() {
        let session = TasbihSession.starting(TasbihDhikr.stub(targetCount: 1))

        let outcome = TasbihUseCase.counting(session)

        #expect(outcome.completedLap)
        #expect(outcome.session.completedLaps == 1)
        #expect(outcome.session.currentCount == 0)
    }

    // MARK: Totals

    /// `totalCount` has to keep rising across a lap boundary — the haptic is triggered on it, and
    /// a number that fell back to zero would fire on the wrong edge.
    @Test func theTotalKeepsRisingAcrossALapBoundary() {
        var session = counting(TasbihSession.starting(dhikr), times: 32)
        #expect(session.totalCount == 32)

        session = TasbihUseCase.counting(session).session
        #expect(session.totalCount == 33)

        session = TasbihUseCase.counting(session).session
        #expect(session.totalCount == 34)
    }

    // MARK: Sessions that no longer match their preset

    /// A corpus rebuild can lower a target under a session that is already past it. The lap has
    /// to be closeable — with `==` the count would climb forever and never wrap.
    @Test func aCountAlreadyPastAShrunkenTargetStillClosesItsLap() {
        let session = TasbihSession(dhikrID: "subhanallah", currentCount: 50, targetCount: 33)

        let outcome = TasbihUseCase.counting(session)

        #expect(outcome.completedLap)
        #expect(outcome.session.currentCount == 0)
        #expect(outcome.session.completedLaps == 1)
    }

    /// A target of zero would be a lap that can never be completed. The session clamps it.
    @Test func anImpossibleTargetIsClampedRatherThanTrusted() {
        let session = TasbihSession(dhikrID: "x", targetCount: 0)

        #expect(session.targetCount == 1)
        #expect(TasbihUseCase.counting(session).completedLap)
    }

    // MARK: The clock

    @Test func countingStampsTheSession() {
        let instant = Date(timeIntervalSince1970: 1_000_000)
        let session = TasbihSession(
            dhikrID: "subhanallah",
            targetCount: 33,
            lastUpdated: Date(timeIntervalSince1970: 0)
        )

        let outcome = TasbihUseCase.counting(session, now: instant)

        #expect(outcome.session.lastUpdated == instant)
    }
}

/// The other half of the use case: composing two stores that know nothing about each other.
struct TasbihUseCaseCompositionTests {

    private let dhikr = TasbihDhikr.stub(targetCount: 33)

    private func makeUseCase(
        catalog: StubTasbihCatalog = StubTasbihCatalog(),
        progress: StubTasbihProgress = StubTasbihProgress(),
        now: @escaping @Sendable () -> Date = Date.init
    ) -> TasbihUseCase {
        TasbihUseCase(catalog: catalog, progress: progress, now: now)
    }

    @Test func presetsComeStraightFromTheCatalog() async throws {
        let expected = [TasbihDhikr.stub(id: "a"), TasbihDhikr.stub(id: "b")]
        let useCase = makeUseCase(catalog: StubTasbihCatalog(.success(expected)))

        #expect(try await useCase.presets(in: .english) == expected)
    }

    @Test func theLanguageIsForwardedToTheCatalog() async throws {
        let catalog = StubTasbihCatalog()
        let useCase = makeUseCase(catalog: catalog)

        _ = try await useCase.presets(in: .arabic)

        #expect(await catalog.requestedLanguages == [.arabic])
    }

    /// "Never counted" and "counted to zero" are the same thing to a screen, so the use case
    /// collapses the optional rather than making every caller do it.
    @Test func anUncountedPresetGetsAFreshSession() async throws {
        let useCase = makeUseCase()

        let session = try await useCase.session(for: dhikr)

        #expect(session.dhikrID == dhikr.id)
        #expect(session.currentCount == 0)
        #expect(session.completedLaps == 0)
        #expect(session.targetCount == 33)
    }

    @Test func aCountedPresetGetsWhatWasStored() async throws {
        let stored = TasbihSession(
            dhikrID: dhikr.id,
            currentCount: 7,
            targetCount: 33,
            completedLaps: 2
        )
        let useCase = makeUseCase(progress: StubTasbihProgress(seeded: [stored]))

        #expect(try await useCase.session(for: dhikr) == stored)
    }

    /// A lap someone is inside finishes under the rules it began with. Moving them from 20 of 33
    /// to 20 of 100 because the corpus was rebuilt would be a data change rewriting their history.
    @Test func aStoredTargetSurvivesAPresetWhoseTargetChanged() async throws {
        let stored = TasbihSession(dhikrID: "subhanallah", currentCount: 20, targetCount: 33)
        let useCase = makeUseCase(progress: StubTasbihProgress(seeded: [stored]))

        let session = try await useCase.session(for: TasbihDhikr.stub(targetCount: 100))

        #expect(session.targetCount == 33)
    }

    @Test func savingReachesTheRepository() async throws {
        let progress = StubTasbihProgress()
        let useCase = makeUseCase(progress: progress)
        let session = TasbihSession(dhikrID: dhikr.id, currentCount: 5, targetCount: 33)

        try await useCase.save(session)

        #expect(await progress.savedSessions == [session])
    }

    @Test func resettingClearsTheStoreAndHandsBackAnEmptySession() async throws {
        let stored = TasbihSession(dhikrID: dhikr.id, currentCount: 30, targetCount: 33)
        let progress = StubTasbihProgress(seeded: [stored])
        let useCase = makeUseCase(progress: progress)

        let session = try await useCase.reset(dhikr)

        #expect(await progress.resetIdentifiers == [dhikr.id])
        #expect(session.currentCount == 0)
        #expect(session.completedLaps == 0)
        #expect(try await progress.session(for: dhikr.id) == nil)
    }

    @Test func aFailureIsPropagatedRatherThanSwallowed() async {
        let useCase = makeUseCase(catalog: StubTasbihCatalog(.failure(TasbihStubError())))

        await #expect(throws: TasbihStubError.self) {
            try await useCase.presets(in: .english)
        }
    }
}
