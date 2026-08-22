//
//  HadithViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The three screens' state machine, driven against a stub.
@MainActor
struct HadithViewModelTests {

    private func makeViewModel(
        repository: StubHadithRepository = StubHadithRepository(),
        progress: StubHadithProgressRepository = StubHadithProgressRepository(),
        memorization: StubHadithMemorizationRepository = StubHadithMemorizationRepository()
    ) -> HadithViewModel {
        HadithViewModel(
            useCase: GetHadithUseCase(repository: repository),
            progress: HadithProgressUseCase(progress: progress, corpus: repository),
            memorize: MemorizeHadithUseCase(memorization: memorization, corpus: repository),
            clock: TestClock(Date(timeIntervalSince1970: 1_750_000_000))
        )
    }

    // MARK: The collections

    @Test func itStartsLoading() {
        #expect(makeViewModel().collections == .loading)
    }

    @Test func itShowsWhatTheCorpusReturned() async {
        let viewModel = makeViewModel()

        await viewModel.loadCollections()

        #expect(viewModel.collections == .ready([.stub()]))
    }

    /// A corpus that cannot be opened is a packaging fault, not something the reader did — so it
    /// gets its own case rather than an empty list, which would read as "there are no hadith".
    @Test func aCorpusThatCannotBeReadIsUnavailable() async {
        let viewModel = makeViewModel(
            repository: StubHadithRepository(collections: .failure(HadithStubError()))
        )

        await viewModel.loadCollections()

        #expect(viewModel.collections == .unavailable)
    }

    // MARK: The divisions

    @Test func itLoadsTheDivisionsOfTheCollectionItWasAskedFor() async {
        let repository = StubHadithRepository()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadBooks(in: "muslim")

        #expect(viewModel.books == .ready([.stub()]))
        #expect(repository.requests == [.books("muslim")])
    }

    @Test func divisionsThatCannotBeReadAreUnavailable() async {
        let viewModel = makeViewModel(
            repository: StubHadithRepository(books: .failure(HadithStubError()))
        )

        await viewModel.loadBooks(in: "bukhari")

        #expect(viewModel.books == .unavailable)
    }

    // MARK: The reading

    @Test func readingCarriesTheDivisionAndItsNarrationsTogether() async {
        let viewModel = makeViewModel()
        let reference = BookReference(collection: "bukhari", number: 1)

        await viewModel.loadReading(reference)

        #expect(viewModel.reading == .ready(.init(book: .stub(), hadiths: [.stub()])))
    }

    /// The screen fetches the division rather than taking it from the list above it, so that it
    /// can be opened without that list having been drawn. This is the check that it does.
    @Test func readingFetchesItsOwnDivision() async {
        let repository = StubHadithRepository()
        let viewModel = makeViewModel(repository: repository)
        let reference = BookReference(collection: "bukhari", number: 1)

        await viewModel.loadReading(reference)

        #expect(repository.requests == [.book(reference), .hadiths(reference)])
    }

    /// A reference to a division the corpus does not have. There is nothing to show and nothing
    /// the reader can do, which is `unavailable` exactly — and it must not be a blank screen
    /// with a title over it.
    @Test func aDivisionTheCorpusLacksIsUnavailable() async {
        let viewModel = makeViewModel()

        await viewModel.loadReading(BookReference(collection: "bukhari", number: 99))

        #expect(viewModel.reading == .unavailable)
    }

    @Test func narrationsThatCannotBeReadAreUnavailable() async {
        let viewModel = makeViewModel(
            repository: StubHadithRepository(hadiths: .failure(HadithStubError()))
        )

        await viewModel.loadReading(BookReference(collection: "bukhari", number: 1))

        #expect(viewModel.reading == .unavailable)
    }

    // MARK: Search

    @Test func nothingIsSearchedForUntilSomethingIsTyped() async {
        let repository = StubHadithRepository()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.search()

        #expect(viewModel.searchPhase == .idle)
        #expect(repository.requests.isEmpty)
    }

    /// Punctuation alone folds to no tokens, so it is not a search — and the collections stay on
    /// screen rather than being replaced by an empty result.
    @Test(arguments: ["   ", "؟ ،"])
    func punctuationAloneIsNotASearch(text: String) async {
        let repository = StubHadithRepository()
        let viewModel = makeViewModel(repository: repository)

        viewModel.searchText = text
        await viewModel.search()

        #expect(!viewModel.isSearching)
        #expect(viewModel.searchPhase == .idle)
        #expect(repository.requests.isEmpty)
    }

    @Test func aSearchThatFindsSomethingShowsIt() async {
        let found = HadithSearchResults(hadiths: [.stub()], total: 1)
        let repository = StubHadithRepository(search: .success(found))
        let viewModel = makeViewModel(repository: repository)

        viewModel.searchText = "الأعمال"
        await viewModel.search()

        #expect(viewModel.isSearching)
        #expect(viewModel.searchPhase == .results(found))
        #expect(repository.requests == [.search(ArabicSearchQuery("الأعمال"))])
    }

    /// Searched and found nothing, which is a different thing from not having looked — and the
    /// screen says so rather than showing the hint it shows before a query.
    @Test func aSearchThatFindsNothingIsEmptyRatherThanIdle() async {
        let viewModel = makeViewModel(
            repository: StubHadithRepository(search: .success(.none))
        )

        viewModel.searchText = "زقفونة"
        await viewModel.search()

        #expect(viewModel.searchPhase == .empty)
    }

    @Test func aSearchThatCannotReadTheCorpusIsUnavailable() async {
        let viewModel = makeViewModel(
            repository: StubHadithRepository(search: .failure(HadithStubError()))
        )

        viewModel.searchText = "الأعمال"
        await viewModel.search()

        #expect(viewModel.searchPhase == .unavailable)
    }

    /// Clearing puts the collections back. Called when a result is opened, so that coming back
    /// from a narration does not land on the search that found it.
    @Test func clearingTheSearchPutsTheCollectionsBack() async {
        let viewModel = makeViewModel(
            repository: StubHadithRepository(
                search: .success(HadithSearchResults(hadiths: [.stub()], total: 1))
            )
        )

        viewModel.searchText = "الأعمال"
        await viewModel.search()
        viewModel.clearSearch()

        #expect(!viewModel.isSearching)
        #expect(viewModel.searchPhase == .idle)
    }

    // MARK: The reader's own marks

    @Test func nothingIsKeptToBeginWith() async {
        let viewModel = makeViewModel()

        await viewModel.loadProgress()

        #expect(viewModel.bookmarks.isEmpty)
        #expect(viewModel.lastRead == nil)
    }

    @Test func keptNarrationsArriveWithTheirText() async {
        let hadith = Hadith.stub(number: 1, text: "الأول")
        let viewModel = makeViewModel(
            repository: StubHadithRepository(hadiths: .success([hadith])),
            progress: StubHadithProgressRepository(bookmarks: [HadithBookmark(hadith)])
        )

        await viewModel.loadProgress()

        #expect(viewModel.bookmarks.map(\.id) == [hadith.id])
        #expect(viewModel.bookmarkedIDs == [hadith.id])
        #expect(viewModel.isBookmarked(hadith))
    }

    /// The button flips before the write lands, so it changes under the reader's finger rather
    /// than a frame later.
    @Test func togglingKeepsANarration() async {
        let hadith = Hadith.stub()
        let store = StubHadithProgressRepository()
        let viewModel = makeViewModel(
            repository: StubHadithRepository(hadiths: .success([hadith])),
            progress: store
        )

        await viewModel.toggleBookmark(hadith)

        #expect(viewModel.isBookmarked(hadith))
        #expect(store.stored.map(\.id) == [hadith.id])
    }

    @Test func togglingAgainForgetsIt() async {
        let hadith = Hadith.stub()
        let store = StubHadithProgressRepository(bookmarks: [HadithBookmark(hadith)])
        let viewModel = makeViewModel(
            repository: StubHadithRepository(hadiths: .success([hadith])),
            progress: store
        )

        await viewModel.loadProgress()
        await viewModel.toggleBookmark(hadith)

        #expect(!viewModel.isBookmarked(hadith))
        #expect(store.stored.isEmpty)
    }

    /// A store that will not write must not leave the button showing a state nothing was written
    /// for — so the optimistic flip is put back where the store says it is.
    @Test func aFailedToggleIsPutBack() async {
        let hadith = Hadith.stub()
        let viewModel = makeViewModel(
            repository: StubHadithRepository(hadiths: .success([hadith])),
            progress: StubHadithProgressRepository(failure: HadithStubError())
        )

        await viewModel.toggleBookmark(hadith)

        #expect(!viewModel.isBookmarked(hadith))
    }

    /// **The write must not lose the race with the read.** Popping the reading screen fires the
    /// position write while the list underneath reloads; `loadProgress()` awaits the parked task,
    /// so the position that comes back is the one just written.
    @Test func thePositionWriteIsAwaitedBeforeTheListReloads() async {
        let store = StubHadithProgressRepository()
        let viewModel = makeViewModel(progress: store)
        let book = BookReference(collection: "muslim", number: 12)

        viewModel.recordLastRead(book)
        await viewModel.loadProgress()

        #expect(viewModel.lastRead?.book == book)
    }

    /// A store that will not read costs the reader their marks, not the collections. The sections
    /// simply do not appear.
    @Test func aStoreThatCannotBeReadLeavesTheMarksEmpty() async {
        let viewModel = makeViewModel(
            progress: StubHadithProgressRepository(failure: HadithStubError())
        )

        await viewModel.loadProgress()

        #expect(viewModel.bookmarks.isEmpty)
        #expect(viewModel.lastRead == nil)
    }
}

/// Where the tab is, and how a search result gets two levels down in one move.
@MainActor
struct HadithCoordinatorTests {

    private let collection = HadithCollection.stub()

    @Test func itStartsAtTheCollections() {
        #expect(HadithCoordinator().path.isEmpty)
    }

    @Test func openingACollectionPushesOneLevel() {
        let coordinator = HadithCoordinator()

        coordinator.open(collection)

        #expect(coordinator.path == [.collection(collection)])
    }

    @Test func openingADivisionPushesOnTopOfIt() {
        let coordinator = HadithCoordinator()
        let reference = BookReference(collection: "bukhari", number: 1)

        coordinator.open(collection)
        coordinator.open(reference)

        #expect(coordinator.path == [.collection(collection), .book(reference)])
    }

    /// **The reason this coordinator holds a path at all.** A chain of
    /// `navigationDestination(item:)` cannot land two levels in one update, because the second
    /// destination is declared by the first destination's view. Both routes go on at once here.
    @Test func openingANarrationLandsInItsDivisionInOneMove() {
        let coordinator = HadithCoordinator()
        let hadith = Hadith.stub(bookNumber: 7, number: 42)

        coordinator.open(hadith, in: collection)

        #expect(coordinator.path == [
            .collection(collection),
            .book(BookReference(collection: "bukhari", number: 7))
        ])
        #expect(coordinator.scrollTarget == HadithID(collection: "bukhari", number: 42))
    }

    /// The target is consumed once. One that outlived the scroll would drag the reader back to it
    /// on every redraw of a screen they are scrolling.
    @Test func theScrollTargetIsForgottenOnceItIsUsed() {
        let coordinator = HadithCoordinator()

        coordinator.open(Hadith.stub(number: 42), in: collection)
        coordinator.clearScrollTarget()

        #expect(coordinator.scrollTarget == nil)
    }

    /// Opening a collection normally starts at the top of it, rather than at wherever a search
    /// result last left the target.
    @Test func openingACollectionClearsAnyScrollTarget() {
        let coordinator = HadithCoordinator()

        coordinator.open(Hadith.stub(number: 42), in: collection)
        coordinator.open(collection)

        #expect(coordinator.scrollTarget == nil)
    }
}

/// The span a narration is cited by, which is the one piece of logic in this feature's Domain.
struct HadithReferenceTests {

    @Test func aReferenceWithNoLastNumberIsASingleNumber() {
        let reference = HadithReference(collection: "bukhari", first: 1)

        #expect(reference.last == 1)
        #expect(!reference.isSpan)
        #expect(reference.covers(1))
        #expect(!reference.covers(2))
    }

    @Test func aSpanCoversEveryNumberInIt() {
        let reference = HadithReference(collection: "bukhari", first: 5709, last: 5712)

        #expect(reference.isSpan)
        #expect(reference.covers(5709))
        #expect(reference.covers(5711))
        #expect(reference.covers(5712))
        #expect(!reference.covers(5713))
    }

    /// A last number below the first would make `first...last` trap. It cannot come from the
    /// corpus — the schema forbids it — but this type is also built by hand in tests and
    /// previews, and a range that crashes is a worse answer than a range of one.
    @Test func aLastNumberBelowTheFirstIsIgnored() {
        let reference = HadithReference(collection: "bukhari", first: 100, last: 1)

        #expect(reference.last == 100)
        #expect(!reference.isSpan)
    }
}
