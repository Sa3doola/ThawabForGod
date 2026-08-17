//
//  NamesViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct NamesViewModelTests {

    /// `nonisolated` so it can serve as a default argument below — default arguments are
    /// evaluated at the call site, which is not this `@MainActor` suite. Safe because
    /// `DivineName` is `Sendable` and the array never changes.
    nonisolated private static let sample = [
        DivineName.stub(id: 1, arabic: "الرَّحْمَنُ", transliteration: "Ar Rahmaan", meaning: "The Beneficent"),
        DivineName.stub(id: 2, arabic: "الرَّحِيمُ", transliteration: "Ar Raheem", meaning: "The Merciful"),
        DivineName.stub(id: 3, arabic: "الْمَلِكُ", transliteration: "Al Malik", meaning: "The King"),
        DivineName.stub(id: 4, arabic: "الْقُدُّوسُ", transliteration: "Al Quddus", meaning: "The Purest")
    ]

    /// Built inside rather than defaulted in the signature — default arguments are evaluated in a
    /// nonisolated context, and `NamesViewModel` is `@MainActor`.
    private func makeViewModel(
        _ result: Result<[DivineName], NamesStubError> = .success(NamesViewModelTests.sample),
        tips: SpyNamesTipReporting? = nil
    ) -> (NamesViewModel, SpyNamesTipReporting) {
        let tips = tips ?? SpyNamesTipReporting()
        let viewModel = NamesViewModel(
            useCase: GetNamesUseCase(repository: StubNamesRepository(result)),
            tips: tips
        )
        return (viewModel, tips)
    }

    // MARK: Loading

    @Test func loadingPopulatesTheGrid() async {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.phase == .loading)

        await viewModel.load(in: .english)

        #expect(viewModel.phase == .ready(Self.sample))
        #expect(viewModel.matches == Self.sample)
        #expect(viewModel.allNames.count == 4)
    }

    @Test func anUnreadableCorpusLeavesTheGridUnavailable() async {
        let (viewModel, _) = makeViewModel(.failure(NamesStubError()))

        await viewModel.load(in: .english)

        #expect(viewModel.phase == .unavailable)
        #expect(viewModel.matches.isEmpty)
        #expect(viewModel.allNames.isEmpty)
    }

    @Test func openingTheGridIsDonatedAndOpeningANameRetiresTheTip() async {
        let (viewModel, tips) = makeViewModel()

        await viewModel.load(in: .english)
        viewModel.nameOpened()

        #expect(tips.openedCalls == 1)
        #expect(tips.nameOpenedCalls == 1)
    }

    // MARK: Searching

    @Test func anEmptyQueryMatchesEverything() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load(in: .english)

        #expect(viewModel.isSearching == false)
        #expect(viewModel.matches.count == 4)
    }

    @Test func searchingTheTransliterationNarrowsTheList() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load(in: .english)

        viewModel.query = "Rah"

        #expect(viewModel.isSearching)
        #expect(viewModel.matches.map(\.order) == [1, 2])
    }

    @Test func searchingTheMeaningWorksToo() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load(in: .english)

        viewModel.query = "king"

        #expect(viewModel.matches.map(\.order) == [3])
    }

    @Test func searchIsCaseInsensitive() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load(in: .english)

        viewModel.query = "MALIK"

        #expect(viewModel.matches.map(\.order) == [3])
    }

    /// The corpus stores fully vowelled Arabic and nobody types the harakat, so a literal
    /// `contains` would find الرحمن only for someone who typed الرَّحْمَنُ exactly. This is the
    /// check that the diacritic-insensitive option is actually doing its job.
    @Test func searchingArabicIgnoresDiacritics() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load(in: .english)

        viewModel.query = "الرحمن"

        #expect(viewModel.matches.map(\.order) == [1])
    }

    @Test func aQueryThatMatchesNothingEmptiesTheList() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load(in: .english)

        viewModel.query = "zzzz"

        #expect(viewModel.matches.isEmpty)
        #expect(viewModel.isSearching)
        // The full list is still there behind the filter.
        #expect(viewModel.allNames.count == 4)
    }

    @Test func whitespaceAloneIsNotASearch() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load(in: .english)

        viewModel.query = "   "

        #expect(viewModel.isSearching == false)
        #expect(viewModel.matches.count == 4)
    }

    @Test func clearingTheSearchRestoresEverything() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load(in: .english)
        viewModel.query = "king"
        #expect(viewModel.matches.count == 1)

        viewModel.clearSearch()

        #expect(viewModel.query.isEmpty)
        #expect(viewModel.matches.count == 4)
    }

    /// An Arabic reader has no transliteration or meaning to match on, so search has to keep
    /// working over the names themselves.
    @Test func searchStillWorksWhenThereIsOnlyArabicToMatch() async {
        let arabicOnly = Self.sample.map {
            DivineName.stub(id: $0.order, arabic: $0.arabic, transliteration: nil, meaning: nil)
        }
        let (viewModel, _) = makeViewModel(.success(arabicOnly))
        await viewModel.load(in: .arabic)

        viewModel.query = "الملك"

        #expect(viewModel.matches.map(\.order) == [3])
    }

    /// A search typed before the names arrive must survive the load rather than being silently
    /// dropped — `load` re-filters at the end for exactly this reason.
    @Test func aQueryTypedBeforeLoadingIsAppliedOnceTheNamesArrive() async {
        let (viewModel, _) = makeViewModel()

        viewModel.query = "king"
        await viewModel.load(in: .english)

        #expect(viewModel.matches.map(\.order) == [3])
    }

    // MARK: Reloading

    @Test func reloadingInAnotherLanguageRefreshesTheList() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load(in: .english)
        #expect(viewModel.matches.count == 4)

        await viewModel.load(in: .arabic)

        #expect(viewModel.phase == .ready(Self.sample))
        #expect(viewModel.matches.count == 4)
    }
}
