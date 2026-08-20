//
//  HomeLayoutRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The store side of the layout: one key, JSON in it, and a default that is never written down.
struct HomeLayoutRepositoryTests {

    @Test func anUntouchedStoreReadsAsTheDefaultAndStaysUntouched() {
        let store = InMemorySettingsStore()

        #expect(HomeLayoutRepository(settingsStore: store).layout() == .default)
        // The project's standing rule: reading a preference must not turn "no preference" into
        // a stored choice.
        #expect(store.string(for: .homeLayout) == nil)
    }

    @Test func savedLayoutsComeBack() {
        let store = InMemorySettingsStore()
        let repository = HomeLayoutRepository(settingsStore: store)

        var layout = HomeLayout.default
        layout.setVisibility(false, of: .lastActivity)
        layout.moveSections(from: IndexSet(integer: 1), to: 4)
        repository.save(layout)

        #expect(store.string(for: .homeLayout) != nil)
        #expect(repository.layout() == layout)
    }

    /// `reset()` clears the key rather than storing the default, so a later change to what the
    /// default *is* still reaches this user.
    @Test func resetClearsTheKeyRatherThanStoringTheDefault() {
        let store = InMemorySettingsStore()
        let repository = HomeLayoutRepository(settingsStore: store)

        var layout = HomeLayout.default
        layout.setVisibility(false, of: .continueReading)
        repository.save(layout)

        repository.reset()

        #expect(store.string(for: .homeLayout) == nil)
        #expect(repository.layout() == .default)
    }

    @Test func anUnreadableStoredValueFallsBackRatherThanTrapping() {
        let store = InMemorySettingsStore(strings: [.homeLayout: "not json"])

        #expect(HomeLayoutRepository(settingsStore: store).layout() == .default)
    }

    @Test func theUseCasesReadWriteAndResetThroughTheRepository() {
        let store = InMemorySettingsStore()
        let repository = HomeLayoutRepository(settingsStore: store)

        var layout = HomeLayout.default
        layout.setVisibility(false, of: .continueReading)

        UpdateHomeLayoutUseCase(repository: repository)(layout)

        #expect(GetHomeLayoutUseCase(repository: repository)() == layout)
        #expect(ResetHomeLayoutUseCase(repository: repository)() == .default)
        #expect(GetHomeLayoutUseCase(repository: repository)() == .default)
    }
}
