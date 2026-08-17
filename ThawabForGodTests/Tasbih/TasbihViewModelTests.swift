//
//  TasbihViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct TasbihViewModelTests {

    private let dhikr = TasbihDhikr.stub(targetCount: 3)

    /// Built inside rather than defaulted in the signature — default arguments are evaluated in a
    /// nonisolated context, and `TasbihViewModel` is `@MainActor`.
    private func makeViewModel(
        catalog: StubTasbihCatalog? = nil,
        progress: StubTasbihProgress? = nil,
        tips: SpyTasbihTipReporting? = nil
    ) -> (TasbihViewModel, StubTasbihProgress, SpyTasbihTipReporting) {
        let catalog = catalog ?? StubTasbihCatalog()
        let progress = progress ?? StubTasbihProgress()
        let tips = tips ?? SpyTasbihTipReporting()

        let viewModel = TasbihViewModel(
            useCase: TasbihUseCase(catalog: catalog, progress: progress),
            tips: tips
        )

        return (viewModel, progress, tips)
    }

    /// Spins until the view model's own unstructured save has landed, the way
    /// `QiblaViewModelTests` waits on a stream — the alternative is a sleep, which is slower and
    /// flakier both.
    private func waitForSaves(_ progress: StubTasbihProgress, toReach count: Int) async {
        while await progress.savedSessions.count < count {
            await Task.yield()
        }
    }

    // MARK: Presets

    @Test func loadingPresetsPopulatesTheList() async {
        let presets = [TasbihDhikr.stub(id: "a"), TasbihDhikr.stub(id: "b")]
        let (viewModel, _, _) = makeViewModel(catalog: StubTasbihCatalog(.success(presets)))
        #expect(viewModel.presetsPhase == .loading)

        await viewModel.loadPresets(in: .english)

        #expect(viewModel.presetsPhase == .ready(presets))
    }

    @Test func anUnreadableCorpusLeavesTheListUnavailable() async {
        let (viewModel, _, _) = makeViewModel(
            catalog: StubTasbihCatalog(.failure(TasbihStubError()))
        )

        await viewModel.loadPresets(in: .english)

        #expect(viewModel.presetsPhase == .unavailable)
    }

    // MARK: Restoring a session

    @Test func selectingAnUncountedPresetStartsAtZero() async {
        let (viewModel, _, _) = makeViewModel()

        await viewModel.select(dhikr)

        #expect(viewModel.currentCount == 0)
        #expect(viewModel.completedLaps == 0)
        #expect(viewModel.targetCount == 3)
        #expect(viewModel.hasUnsavedCount == false)
    }

    /// The whole point of persisting: a count survives the app being killed, which is what this
    /// stands in for.
    @Test func selectingRestoresWhatWasStored() async {
        let stored = TasbihSession(
            dhikrID: dhikr.id,
            currentCount: 2,
            targetCount: 3,
            completedLaps: 5
        )
        let (viewModel, _, _) = makeViewModel(progress: StubTasbihProgress(seeded: [stored]))

        await viewModel.select(dhikr)

        #expect(viewModel.currentCount == 2)
        #expect(viewModel.completedLaps == 5)
        #expect(viewModel.totalCount == 17)
    }

    // MARK: Counting

    @Test func incrementingMovesTheCount() async {
        let (viewModel, _, _) = makeViewModel()
        await viewModel.select(dhikr)

        viewModel.increment()
        viewModel.increment()

        #expect(viewModel.currentCount == 2)
        #expect(viewModel.completedLaps == 0)
        #expect(viewModel.totalCount == 2)
    }

    @Test func reachingTheTargetWrapsAndBanksALap() async {
        let (viewModel, _, _) = makeViewModel()
        await viewModel.select(dhikr)

        for _ in 0..<3 { viewModel.increment() }

        #expect(viewModel.currentCount == 0)
        #expect(viewModel.completedLaps == 1)
        #expect(viewModel.totalCount == 3)
    }

    @Test func incrementingWithNothingSelectedDoesNothing() {
        let (viewModel, _, _) = makeViewModel()

        viewModel.increment()

        #expect(viewModel.currentCount == 0)
        #expect(viewModel.hasUnsavedCount == false)
    }

    @Test func lapProgressTracksTheWayThroughALap() async {
        let (viewModel, _, _) = makeViewModel()
        await viewModel.select(dhikr)

        #expect(viewModel.lapProgress == 0)
        viewModel.increment()
        #expect(abs(viewModel.lapProgress - 1.0 / 3.0) < 0.0001)
    }

    // MARK: When the count reaches the store

    /// The throttle. Taps inside a lap stay in memory — hitting SwiftData a hundred times for a
    /// hundred-tap dhikr is the thing this design exists to avoid.
    @Test func tapsWithinALapAreNotWrittenOut() async {
        let (viewModel, progress, _) = makeViewModel()
        await viewModel.select(dhikr)

        viewModel.increment()
        viewModel.increment()

        #expect(viewModel.hasUnsavedCount)
        #expect(await progress.savedSessions.isEmpty)
    }

    /// And the checkpoint: completing a lap is the moment worth keeping.
    @Test(.timeLimit(.minutes(1)))
    func completingALapWritesTheSessionOut() async {
        let (viewModel, progress, _) = makeViewModel()
        await viewModel.select(dhikr)

        for _ in 0..<3 { viewModel.increment() }

        await waitForSaves(progress, toReach: 1)

        let saved = await progress.savedSessions
        #expect(saved.count == 1)
        #expect(saved.first?.completedLaps == 1)
        #expect(saved.first?.currentCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func leavingTheScreenWritesOutAPartialLap() async {
        let (viewModel, progress, _) = makeViewModel()
        await viewModel.select(dhikr)

        viewModel.increment()
        viewModel.increment()
        await viewModel.persistPendingCount()

        let saved = await progress.savedSessions
        #expect(saved.count == 1)
        #expect(saved.first?.currentCount == 2)
        #expect(viewModel.hasUnsavedCount == false)
    }

    /// Idempotent, because the view fires it from both `onDisappear` and a scene-phase change
    /// without either knowing about the other.
    @Test func persistingTwiceOverWritesOnlyOnce() async {
        let (viewModel, progress, _) = makeViewModel()
        await viewModel.select(dhikr)
        viewModel.increment()

        await viewModel.persistPendingCount()
        await viewModel.persistPendingCount()

        #expect(await progress.savedSessions.count == 1)
    }

    @Test func persistingWithNothingCountedWritesNothing() async {
        let (viewModel, progress, _) = makeViewModel()
        await viewModel.select(dhikr)

        await viewModel.persistPendingCount()

        #expect(await progress.savedSessions.isEmpty)
    }

    /// A failed write must not be mistaken for a successful one — the count stays dirty so the
    /// next checkpoint tries again rather than assuming it is safe.
    @Test func aFailedWriteLeavesTheCountMarkedUnsaved() async {
        let progress = StubTasbihProgress()
        await progress.setFailsToSave(true)
        let (viewModel, _, _) = makeViewModel(progress: progress)
        await viewModel.select(dhikr)
        viewModel.increment()

        await viewModel.persistPendingCount()

        #expect(viewModel.hasUnsavedCount)
    }

    /// Moving between presets is exactly the moment a half-finished lap would otherwise be
    /// dropped on the floor.
    @Test(.timeLimit(.minutes(1)))
    func choosingAnotherPresetFlushesTheOneBeingLeft() async {
        let (viewModel, progress, _) = makeViewModel()
        await viewModel.select(dhikr)
        viewModel.increment()

        await viewModel.select(TasbihDhikr.stub(id: "alhamdulillah", targetCount: 3))

        let saved = await progress.savedSessions
        #expect(saved.count == 1)
        #expect(saved.first?.dhikrID == "subhanallah")
        #expect(saved.first?.currentCount == 1)
        // And the new preset starts clean.
        #expect(viewModel.currentCount == 0)
        #expect(viewModel.hasUnsavedCount == false)
    }

    // MARK: Resetting

    @Test func resettingZeroesEverythingAndClearsTheStore() async {
        let (viewModel, progress, _) = makeViewModel()
        await viewModel.select(dhikr)
        for _ in 0..<4 { viewModel.increment() }

        await viewModel.reset()

        #expect(viewModel.currentCount == 0)
        #expect(viewModel.completedLaps == 0)
        #expect(viewModel.hasUnsavedCount == false)
        #expect(await progress.resetIdentifiers == [dhikr.id])
    }

    // MARK: Tips

    @Test func everyRecitationIsDonatedAndAResetRetiresTheTip() async {
        let (viewModel, _, tips) = makeViewModel()
        await viewModel.select(dhikr)

        viewModel.increment()
        viewModel.increment()
        await viewModel.reset()

        #expect(tips.countedCalls == 2)
        #expect(tips.resetCalls == 1)
    }
}
