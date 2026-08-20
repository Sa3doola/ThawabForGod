//
//  HomeCustomizationViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The arranging screen has no Save button, so what these mostly check is that nothing is lost:
/// every edit reaches the store, and the one still in the air when the screen goes away does too.
@MainActor
struct HomeCustomizationViewModelTests {

    private func makeViewModel(
        store: any SettingsStore = InMemorySettingsStore(),
        onChange: @escaping () -> Void = {}
    ) -> (HomeCustomizationViewModel, HomeLayoutRepository) {
        let repository = HomeLayoutRepository(settingsStore: store)

        let viewModel = HomeCustomizationViewModel(
            getLayout: GetHomeLayoutUseCase(repository: repository),
            updateLayout: UpdateHomeLayoutUseCase(repository: repository),
            resetLayout: ResetHomeLayoutUseCase(repository: repository),
            onChange: onChange
        )

        return (viewModel, repository)
    }

    // MARK: What the rows show

    @Test func onlyAvailableSectionsAndShortcutsAreOffered() {
        let (viewModel, _) = makeViewModel()

        #expect(viewModel.sections.allSatisfy { $0.kind.isAvailable })
        #expect(viewModel.shortcuts.allSatisfy { $0.shortcut.isAvailable })
        #expect(viewModel.sections.first?.kind == .nextPrayer)
    }

    /// The lock, from the screen's side: the row is present and its toggle is dead.
    @Test func thePinnedSectionsToggleIsNotLive() {
        let (viewModel, _) = makeViewModel()

        #expect(viewModel.canToggle(.nextPrayer) == false)

        viewModel.setVisibility(false, of: .nextPrayer)

        #expect(viewModel.layout.isVisible(.nextPrayer))
    }

    // MARK: Editing

    @Test func hidingASectionReachesTheStore() {
        let (viewModel, repository) = makeViewModel()

        viewModel.setVisibility(false, of: .continueReading)
        viewModel.flush()

        #expect(repository.layout().isVisible(.continueReading) == false)
    }

    @Test func reorderingReachesTheStore() {
        let (viewModel, repository) = makeViewModel()

        viewModel.moveSections(from: IndexSet(integer: 1), to: 4)
        viewModel.flush()

        #expect(repository.layout().visibleSections == viewModel.layout.visibleSections)
        #expect(repository.layout().visibleSections.first == .nextPrayer)
    }

    @Test func hidingAShortcutReachesTheStore() {
        let (viewModel, repository) = makeViewModel()

        viewModel.setVisibility(false, of: .qibla)
        viewModel.flush()

        #expect(repository.layout().isVisible(.qibla) == false)
    }

    /// Reordering without a drag, for VoiceOver and switch control — the handles are reachable by
    /// neither.
    @Test func aSectionCanBeMovedOnePlaceByAction() {
        let (viewModel, _) = makeViewModel()

        let before = viewModel.sections.map(\.kind)
        var swapped = before
        swapped.swapAt(1, 2)

        viewModel.move(before[2], by: -1)

        #expect(viewModel.sections.map(\.kind) == swapped)

        viewModel.move(before[2], by: 1)

        #expect(viewModel.sections.map(\.kind) == before)
    }

    /// The pin holds against the accessibility action too, not just against the drag.
    @Test func movingASectionOntoThePinLeavesThePinFirst() {
        let (viewModel, _) = makeViewModel()

        viewModel.move(viewModel.sections[1].kind, by: -1)

        #expect(viewModel.sections.first?.kind == .nextPrayer)
    }

    @Test func movingPastEitherEndDoesNothing() {
        let (viewModel, _) = makeViewModel()

        let before = viewModel.sections.map(\.kind)
        viewModel.move(before[0], by: -1)
        viewModel.move(before[before.count - 1], by: 1)

        #expect(viewModel.sections.map(\.kind) == before)
    }

    // MARK: Reset

    @Test func resetPutsEverythingBackAndClearsTheKey() {
        let store = InMemorySettingsStore()
        let (viewModel, _) = makeViewModel(store: store)

        viewModel.setVisibility(false, of: .continueReading)
        viewModel.flush()
        #expect(store.string(for: .homeLayout) != nil)

        viewModel.reset()

        #expect(viewModel.layout == .default)
        // Cleared rather than overwritten with today's default — the project's standing rule
        // about never storing a preference the user did not choose.
        #expect(store.string(for: .homeLayout) == nil)
    }

    // MARK: Persisting

    /// The debounce, observed rather than asserted about: the write has not landed immediately,
    /// and it lands on its own shortly afterwards.
    @Test(.timeLimit(.minutes(1)))
    func aChangeIsWrittenShortlyWithoutBeingAskedTo() async {
        let (viewModel, repository) = makeViewModel()

        viewModel.setVisibility(false, of: .continueReading)

        while repository.layout().isVisible(.continueReading) {
            await Task.yield()
        }

        #expect(repository.layout().isVisible(.continueReading) == false)
    }

    /// Leaving inside the debounce window is the one failure a screen with no Save button cannot
    /// have.
    @Test func leavingInsideTheDebounceWindowStillWrites() {
        let (viewModel, repository) = makeViewModel()

        viewModel.setVisibility(false, of: .continueReading)
        // No waiting: the task is still asleep.
        #expect(repository.layout().isVisible(.continueReading))

        viewModel.flush()

        #expect(repository.layout().isVisible(.continueReading) == false)
    }

    /// What keeps the Home screen behind this one in step — it re-reads on this signal rather
    /// than waiting to be entered again.
    @Test func everyWriteAnnouncesItself() {
        final class Counter: @unchecked Sendable {
            private let lock = NSLock()
            private var value = 0
            var count: Int { lock.withLock { value } }
            func increment() { lock.withLock { value += 1 } }
        }

        let counter = Counter()
        let (viewModel, _) = makeViewModel(onChange: counter.increment)

        viewModel.setVisibility(false, of: .continueReading)
        viewModel.flush()
        #expect(counter.count == 1)

        viewModel.reset()
        #expect(counter.count == 2)
    }

    /// Both doors push the same view model, so the one opened second has to re-read rather than
    /// draw what it was holding when it was last closed.
    @Test func reloadingPicksUpAChangeMadeElsewhere() {
        let store = InMemorySettingsStore()
        let (viewModel, repository) = makeViewModel(store: store)

        var layout = HomeLayout.default
        layout.setVisibility(false, of: .lastActivity)
        repository.save(layout)

        #expect(viewModel.layout.isVisible(.lastActivity))

        viewModel.reload()

        #expect(viewModel.layout.isVisible(.lastActivity) == false)
    }
}
