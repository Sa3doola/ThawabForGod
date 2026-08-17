//
//  AdhkarViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct AdhkarViewModelTests {

    /// Built inside rather than defaulted in the signature — default arguments are evaluated in
    /// a nonisolated context, and `AdhkarViewModel` is `@MainActor`.
    private func makeViewModel(
        categories: Result<[AdhkarCategory], AdhkarStubError> = .success([.morning, .evening]),
        adhkar: Result<[Dhikr], AdhkarStubError> = .success([])
    ) -> AdhkarViewModel {
        AdhkarViewModel(
            useCase: GetAdhkarUseCase(
                repository: StubAdhkarRepository(categories: categories, adhkar: adhkar)
            )
        )
    }

    // MARK: Loading

    @Test func loadingCategoriesPopulatesTheList() async {
        let viewModel = makeViewModel()
        #expect(viewModel.categoriesPhase == .loading)

        await viewModel.loadCategories()

        #expect(viewModel.categoriesPhase == .ready([.morning, .evening]))
    }

    @Test func anUnreadableCorpusLeavesTheListUnavailable() async {
        let viewModel = makeViewModel(categories: .failure(AdhkarStubError()))

        await viewModel.loadCategories()

        #expect(viewModel.categoriesPhase == .unavailable)
    }

    @Test func loadingACategoryPopulatesTheReadingScreen() async {
        let adhkar = [Dhikr.stub(id: 1), Dhikr.stub(id: 2)]
        let viewModel = makeViewModel(adhkar: .success(adhkar))

        await viewModel.load(.morning, language: .english)

        #expect(viewModel.readingPhase == .ready(adhkar))
        #expect(viewModel.category == .morning)
        #expect(viewModel.totalCount == 2)
    }

    @Test func anUnreadableCategoryLeavesTheReadingScreenUnavailable() async {
        let viewModel = makeViewModel(adhkar: .failure(AdhkarStubError()))

        await viewModel.load(.morning, language: .english)

        #expect(viewModel.readingPhase == .unavailable)
        #expect(viewModel.totalCount == 0)
    }

    // MARK: Counting

    @Test func tappingCountsUpTowardsTheTarget() async {
        let dhikr = Dhikr.stub(repeatCount: 3)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))
        await viewModel.load(.morning, language: .english)

        #expect(viewModel.repeats(of: dhikr) == 0)
        #expect(viewModel.isComplete(dhikr) == false)

        viewModel.countRepeat(of: dhikr)
        viewModel.countRepeat(of: dhikr)

        #expect(viewModel.repeats(of: dhikr) == 2)
        #expect(viewModel.isComplete(dhikr) == false)

        viewModel.countRepeat(of: dhikr)

        #expect(viewModel.repeats(of: dhikr) == 3)
        #expect(viewModel.isComplete(dhikr))
    }

    /// Clamped rather than left to run on: the screen shows the count against the target, and
    /// "12 of 10" is not a state anyone wants to read.
    @Test func countingPastTheTargetDoesNothing() async {
        let dhikr = Dhikr.stub(repeatCount: 2)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))
        await viewModel.load(.morning, language: .english)

        for _ in 0..<10 {
            viewModel.countRepeat(of: dhikr)
        }

        #expect(viewModel.repeats(of: dhikr) == 2)
    }

    @Test func resettingStartsADhikrAgain() async {
        let dhikr = Dhikr.stub(repeatCount: 3)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))
        await viewModel.load(.morning, language: .english)

        viewModel.countRepeat(of: dhikr)
        viewModel.resetRepeats(of: dhikr)

        #expect(viewModel.repeats(of: dhikr) == 0)
        #expect(viewModel.isComplete(dhikr) == false)
    }

    /// Each dhikr counts on its own — the counters are keyed by id, not shared by the screen.
    @Test func countersAreKeptPerDhikr() async {
        let first = Dhikr.stub(id: 1, repeatCount: 3)
        let second = Dhikr.stub(id: 2, repeatCount: 3)
        let viewModel = makeViewModel(adhkar: .success([first, second]))
        await viewModel.load(.morning, language: .english)

        viewModel.countRepeat(of: first)

        #expect(viewModel.repeats(of: first) == 1)
        #expect(viewModel.repeats(of: second) == 0)
    }

    // MARK: Progress

    @Test func progressCountsOnlyTheAdhkarThatAreFinished() async {
        let first = Dhikr.stub(id: 1, repeatCount: 1)
        let second = Dhikr.stub(id: 2, repeatCount: 2)
        let viewModel = makeViewModel(adhkar: .success([first, second]))
        await viewModel.load(.morning, language: .english)

        #expect(viewModel.completedCount == 0)

        viewModel.countRepeat(of: first)
        #expect(viewModel.completedCount == 1)

        viewModel.countRepeat(of: second)
        #expect(viewModel.completedCount == 1, "a part-finished dhikr does not count")

        viewModel.countRepeat(of: second)
        #expect(viewModel.completedCount == 2)
        #expect(viewModel.completedCount == viewModel.totalCount)
    }

    // MARK: What a reload does to the counts

    /// 16 of the corpus's 34 adhkar sit under both headings. Saying one ten times in the morning
    /// must not leave it already counted when the evening list is opened.
    @Test func movingToAnotherCategoryClearsTheCounts() async {
        let dhikr = Dhikr.stub(repeatCount: 3)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))

        await viewModel.load(.morning, language: .english)
        viewModel.countRepeat(of: dhikr)
        #expect(viewModel.repeats(of: dhikr) == 1)

        await viewModel.load(.evening, language: .english)

        #expect(viewModel.category == .evening)
        #expect(viewModel.repeats(of: dhikr) == 0)
    }

    /// Changing language re-fetches the same category's text. It is the same reading session, so
    /// the reader keeps their place — losing it would punish anyone who switches to check a
    /// translation mid-way through a hundred repetitions.
    @Test func rereadingTheSameCategoryInAnotherLanguageKeepsTheCounts() async {
        let dhikr = Dhikr.stub(repeatCount: 3)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))

        await viewModel.load(.morning, language: .english)
        viewModel.countRepeat(of: dhikr)

        await viewModel.load(.morning, language: .arabic)

        #expect(viewModel.repeats(of: dhikr) == 1)
    }
}
