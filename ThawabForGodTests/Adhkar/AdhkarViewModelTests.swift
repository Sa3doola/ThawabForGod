//
//  AdhkarViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct AdhkarViewModelTests {

    nonisolated private static let chapters: [AdhkarCategory] = [
        .stub(id: "morning-evening", titleArabic: "أذكار الصباح والمساء",
              titleEnglish: "Morning & evening", group: .daily, sortOrder: 1),
        .stub(id: "sleep", titleArabic: "أذكار النوم",
              titleEnglish: "Before sleeping", group: .daily, sortOrder: 2),
        .stub(id: "entering-the-market", titleArabic: "دعاء دخول السوق",
              titleEnglish: "Entering the market", group: .travel, sortOrder: 98),
        .stub(id: "wind", titleArabic: "دعاء الريح",
              titleEnglish: "The wind", group: .nature, sortOrder: 61),
    ]

    /// Built inside rather than defaulted in the signature — default arguments are evaluated in
    /// a nonisolated context, and `AdhkarViewModel` is `@MainActor`.
    private func makeViewModel(
        categories: Result<[AdhkarCategory], AdhkarStubError> = .success(chapters),
        adhkar: Result<[Dhikr], AdhkarStubError> = .success([]),
        settingsStore: any SettingsStore = InMemorySettingsStore()
    ) -> AdhkarViewModel {
        AdhkarViewModel(
            useCase: GetAdhkarUseCase(
                repository: StubAdhkarRepository(categories: categories, adhkar: adhkar)
            ),
            settingsStore: settingsStore
        )
    }

    // MARK: Loading

    @Test func loadingCategoriesPopulatesTheList() async {
        let viewModel = makeViewModel()
        #expect(viewModel.categoriesPhase == .loading)

        await viewModel.loadCategories()

        #expect(viewModel.categoriesPhase == .ready(Self.chapters))
    }

    @Test func anUnreadableCorpusLeavesTheListUnavailable() async {
        let viewModel = makeViewModel(categories: .failure(AdhkarStubError()))

        await viewModel.loadCategories()

        #expect(viewModel.categoriesPhase == .unavailable)
        #expect(viewModel.sections.isEmpty)
    }

    @Test func loadingAChapterPopulatesTheReadingScreen() async {
        let adhkar = [Dhikr.stub(id: 1), Dhikr.stub(id: 2)]
        let viewModel = makeViewModel(adhkar: .success(adhkar))

        await viewModel.load(categoryID: "sleep")

        #expect(viewModel.readingPhase == .ready(adhkar))
        #expect(viewModel.category?.id == "sleep")
        #expect(viewModel.totalCount == 2)
    }

    /// A slug this corpus has never heard of is what a shortcut saved by an older install hands
    /// this screen. It says so rather than trapping.
    @Test func anUnknownSlugLeavesTheReadingScreenUnavailable() async {
        let viewModel = makeViewModel()

        await viewModel.load(categoryID: "a-chapter-from-another-build")

        #expect(viewModel.readingPhase == .unavailable)
        #expect(viewModel.category == nil)
    }

    @Test func anUnreadableChapterLeavesTheReadingScreenUnavailable() async {
        let viewModel = makeViewModel(adhkar: .failure(AdhkarStubError()))

        await viewModel.load(categoryID: "sleep")

        #expect(viewModel.readingPhase == .unavailable)
        #expect(viewModel.totalCount == 0)
    }

    // MARK: Browsing

    /// The list is cut where the group changes, in the corpus's group order — and a group with
    /// nothing in it never becomes a heading.
    @Test func chaptersAreCutIntoTheirGroups() async {
        let viewModel = makeViewModel()
        await viewModel.loadCategories()

        #expect(viewModel.sections.map(\.group) == [.daily, .travel, .nature])
        #expect(viewModel.sections.first?.categories.map(\.id) == ["morning-evening", "sleep"])
    }

    @Test func searchingNarrowsTheListAndDropsEmptyGroups() async {
        let viewModel = makeViewModel()
        await viewModel.loadCategories()

        viewModel.searchText = "market"

        #expect(viewModel.sections.map(\.group) == [.travel])
        #expect(viewModel.sections.first?.categories.map(\.id) == ["entering-the-market"])
        #expect(viewModel.isSearching)
    }

    /// A reader typing `mosq` has not finished the word yet, and a search that only answers on
    /// the last keystroke reads as a broken one.
    @Test func searchMatchesAPrefixRatherThanAWholeWord() async {
        let viewModel = makeViewModel()
        await viewModel.loadCategories()

        viewModel.searchText = "slee"

        #expect(viewModel.sections.flatMap(\.categories).map(\.id) == ["sleep"])
    }

    @Test func searchIgnoresCaseInTheEnglishTitle() async {
        let viewModel = makeViewModel()
        await viewModel.loadCategories()

        viewModel.searchText = "MARKET"

        #expect(viewModel.sections.flatMap(\.categories).map(\.id) == ["entering-the-market"])
    }

    /// An English interface still finds a chapter typed in Arabic, and the folding is the one the
    /// corpora are indexed with — so hamzas and diacritics on either side do not decide the
    /// answer.
    @Test func searchMatchesTheArabicTitleWhateverTheInterfaceLanguage() async {
        let viewModel = makeViewModel()
        await viewModel.loadCategories()

        viewModel.searchText = "الريح"

        #expect(viewModel.sections.flatMap(\.categories).map(\.id) == ["wind"])
    }

    /// Every word has to match something, or `wind market` would find both.
    @Test func allTheTypedWordsMustMatch() async {
        let viewModel = makeViewModel()
        await viewModel.loadCategories()

        viewModel.searchText = "entering market"
        #expect(viewModel.sections.flatMap(\.categories).map(\.id) == ["entering-the-market"])

        viewModel.searchText = "wind market"
        #expect(viewModel.hasSearchResults == false)
    }

    /// Punctuation alone is not a search. Without this the screen would show "nothing matches"
    /// for a stray character the reader is about to delete.
    @Test func aQueryOfPunctuationAloneIsNotASearch() async {
        let viewModel = makeViewModel()
        await viewModel.loadCategories()

        viewModel.searchText = "  -  "

        #expect(viewModel.isSearching == false)
        #expect(viewModel.sections.flatMap(\.categories).count == Self.chapters.count)
    }

    // MARK: Counting

    @Test func tappingCountsUpTowardsTheTarget() async {
        let dhikr = Dhikr.stub(repeatCount: 3)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))
        await viewModel.load(categoryID: "sleep")

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

    /// The reading screen turns this into the move to the next dhikr and the second haptic, both
    /// of which belong to the crossing rather than to the count.
    @Test func onlyTheTapThatFinishesADhikrReportsCompletion() async {
        let dhikr = Dhikr.stub(repeatCount: 2)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))
        await viewModel.load(categoryID: "sleep")

        #expect(viewModel.countRepeat(of: dhikr) == false)
        #expect(viewModel.countRepeat(of: dhikr))
        // Already finished: a tap that changes nothing must not fire the haptic again.
        #expect(viewModel.countRepeat(of: dhikr) == false)
    }

    /// 247 of the 267 adhkar are said once, so one tap finishing a dhikr is the common path
    /// rather than the edge.
    @Test func aDhikrSaidOnceIsFinishedInOneTap() async {
        let dhikr = Dhikr.stub(repeatCount: 1)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))
        await viewModel.load(categoryID: "sleep")

        #expect(viewModel.countRepeat(of: dhikr))
        #expect(viewModel.isComplete(dhikr))
    }

    /// Clamped rather than left to run on: the screen shows the count against the target, and
    /// "12 of 10" is not a state anyone wants to read.
    @Test func countingPastTheTargetDoesNothing() async {
        let dhikr = Dhikr.stub(repeatCount: 2)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))
        await viewModel.load(categoryID: "sleep")

        for _ in 0..<10 {
            viewModel.countRepeat(of: dhikr)
        }

        #expect(viewModel.repeats(of: dhikr) == 2)
    }

    @Test func resettingStartsADhikrAgain() async {
        let dhikr = Dhikr.stub(repeatCount: 3)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))
        await viewModel.load(categoryID: "sleep")

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
        await viewModel.load(categoryID: "sleep")

        viewModel.countRepeat(of: first)

        #expect(viewModel.repeats(of: first) == 1)
        #expect(viewModel.repeats(of: second) == 0)
    }

    // MARK: Advancing

    @Test func theNextDhikrIsTheOneAfterItInTheChapter() async {
        let first = Dhikr.stub(id: 1)
        let second = Dhikr.stub(id: 2)
        let viewModel = makeViewModel(adhkar: .success([first, second]))
        await viewModel.load(categoryID: "sleep")

        #expect(viewModel.dhikr(after: first) == second)
        #expect(viewModel.dhikr(after: second) == nil, "the last dhikr advances to nothing")
    }

    // MARK: Progress

    @Test func progressCountsOnlyTheAdhkarThatAreFinished() async {
        let first = Dhikr.stub(id: 1, repeatCount: 1)
        let second = Dhikr.stub(id: 2, repeatCount: 2)
        let viewModel = makeViewModel(adhkar: .success([first, second]))
        await viewModel.load(categoryID: "sleep")

        #expect(viewModel.completedCount == 0)
        #expect(viewModel.isChapterComplete == false)

        viewModel.countRepeat(of: first)
        #expect(viewModel.completedCount == 1)

        viewModel.countRepeat(of: second)
        #expect(viewModel.completedCount == 1, "a part-finished dhikr does not count")

        viewModel.countRepeat(of: second)
        #expect(viewModel.completedCount == 2)
        #expect(viewModel.isChapterComplete)
    }

    /// An empty chapter is not a finished one — otherwise a corpus fault would draw the "chapter
    /// complete" seal over a screen with nothing on it.
    @Test func anEmptyChapterIsNotComplete() async {
        let viewModel = makeViewModel(adhkar: .success([]))
        await viewModel.load(categoryID: "sleep")

        #expect(viewModel.isChapterComplete == false)
    }

    // MARK: What a reload does to the counts

    @Test func movingToAnotherChapterClearsTheCounts() async {
        let dhikr = Dhikr.stub(repeatCount: 3)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))

        await viewModel.load(categoryID: "sleep")
        viewModel.countRepeat(of: dhikr)
        #expect(viewModel.repeats(of: dhikr) == 1)

        await viewModel.load(categoryID: "wind")

        #expect(viewModel.category?.id == "wind")
        #expect(viewModel.repeats(of: dhikr) == 0)
    }

    /// Re-running the task for the same chapter — which SwiftUI does on a redraw the `id` did not
    /// change for — is the same reading session, so the taps stand. Losing them would punish
    /// anyone who backgrounds the app mid-way through a hundred repetitions.
    @Test func reloadingTheSameChapterKeepsTheCounts() async {
        let dhikr = Dhikr.stub(repeatCount: 3)
        let viewModel = makeViewModel(adhkar: .success([dhikr]))

        await viewModel.load(categoryID: "sleep")
        viewModel.countRepeat(of: dhikr)

        await viewModel.load(categoryID: "sleep")

        #expect(viewModel.repeats(of: dhikr) == 1)
    }

    // MARK: Text size

    /// The rule the whole settings layer is built on: a stored preference outranks the device
    /// forever, so nothing is written until the reader moves the control.
    @Test func nothingIsStoredUntilTheReaderChangesTheSize() {
        let store = InMemorySettingsStore()
        let viewModel = makeViewModel(settingsStore: store)

        #expect(viewModel.textSize == ReaderTypography.fallback.textSize)
        #expect(store.double(for: .adhkarTextSize) == nil)

        viewModel.enlargeText()

        #expect(viewModel.textSize == ReaderTypography.fallback.textSize + ReaderTypography.textSizeStep)
        #expect(store.double(for: .adhkarTextSize) == viewModel.textSize)
    }

    @Test func aStoredSizeIsReadBackOnLaunch() {
        let store = InMemorySettingsStore()
        store.set(30, for: .adhkarTextSize)

        #expect(makeViewModel(settingsStore: store).textSize == 30)
    }

    /// A value hand-edited into the store, or written by a build with a different range, should
    /// produce readable text rather than a page of one glyph.
    @Test func aSizeOutsideTheRangeIsClamped() {
        let store = InMemorySettingsStore()
        store.set(400, for: .adhkarTextSize)

        #expect(makeViewModel(settingsStore: store).textSize == ReaderTypography.textSizeRange.upperBound)
    }

    @Test func theSteppersStopAtTheEndsOfTheRange() {
        let store = InMemorySettingsStore()
        let viewModel = makeViewModel(settingsStore: store)

        viewModel.setTextSize(ReaderTypography.textSizeRange.upperBound)
        #expect(viewModel.canEnlargeText == false)
        #expect(viewModel.canShrinkText)

        viewModel.setTextSize(ReaderTypography.textSizeRange.lowerBound)
        #expect(viewModel.canShrinkText == false)
        #expect(viewModel.canEnlargeText)
    }
}
