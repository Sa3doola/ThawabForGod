//
//  QuranViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct QuranViewModelTests {

    private func viewModel(
        _ repository: StubQuranRepository,
        progress: StubQuranProgressRepository = StubQuranProgressRepository()
    ) -> QuranViewModel {
        QuranViewModel(
            useCase: GetQuranUseCase(repository: repository),
            progress: QuranProgressUseCase(repository: progress)
        )
    }

    // MARK: The list

    @Test func bothListsLoadTogether() async {
        let model = viewModel(
            StubQuranRepository(
                surahs: .success([.stub(id: 1), .stub(id: 2)]),
                juz: .success([.stub(number: 1), .stub(number: 2)])
            )
        )

        await model.loadList()

        #expect(model.surahs.count == 2)
        #expect(model.juz.count == 2)
    }

    /// A failure in either half fails the screen. Half a list is worse than a notice saying the
    /// corpus could not be read: the reader would have no way of knowing what was missing.
    @Test func aFailureInEitherListLeavesTheScreenUnavailable() async {
        let model = viewModel(StubQuranRepository(juz: .failure(QuranStubError())))

        await model.loadList()

        #expect(model.listPhase == .unavailable)
        #expect(model.surahs.isEmpty)
    }

    @Test func theSegmentStartsOnTheChapters() {
        #expect(viewModel(StubQuranRepository()).section == .surahs)
    }

    // MARK: Reading

    @Test func readingAChapterLoadsThatChaptersVerses() async {
        let repository = StubQuranRepository(verses: .success([.stub(surah: 36, number: 1)]))
        let model = viewModel(repository)

        await model.load(.surah(36))

        #expect(repository.requests.contains(.versesInSurah(36)))
        #expect(model.readingPhase != .unavailable)
    }

    @Test func readingAPartLoadsThatPartsVerses() async {
        let repository = StubQuranRepository(verses: .success([.stub(surah: 78, number: 1)]))
        let model = viewModel(repository)

        await model.load(.juz(30))

        #expect(repository.requests.contains(.versesInJuz(30)))
    }

    /// Empty is a failure rather than an empty screen: every chapter and every part has verses,
    /// so nothing coming back means the corpus is not what it claims to be.
    @Test func anEmptyReadingIsTreatedAsAFailure() async {
        let model = viewModel(StubQuranRepository(verses: .success([])))

        await model.load(.surah(1))

        #expect(model.readingPhase == .unavailable)
    }

    @Test func aFailedReadingLeavesTheScreenUnavailable() async {
        let model = viewModel(StubQuranRepository(verses: .failure(QuranStubError())))

        await model.load(.surah(1))

        #expect(model.readingPhase == .unavailable)
    }

    // MARK: The reader's own marks

    private let kursi = VerseReference(surah: 2, verse: 255)

    @Test func loadsKeptVersesAndTheLastPosition() async {
        let progress = StubQuranProgressRepository(
            bookmarks: [QuranBookmark(reference: kursi)],
            position: ReadingPosition(reference: VerseReference(surah: 3, verse: 8))
        )
        let model = viewModel(StubQuranRepository(), progress: progress)

        await model.loadProgress()

        #expect(model.bookmarks.map(\.reference) == [kursi])
        #expect(model.isBookmarked(kursi))
        #expect(model.lastRead?.reference == VerseReference(surah: 3, verse: 8))
    }

    /// The marks come out of a different store than the text does. Failing to read them must not
    /// take the chapters off the screen — the corpus is what this screen is for.
    @Test func failingToReadTheMarksLeavesTheListsAlone() async {
        let model = viewModel(
            StubQuranRepository(surahs: .success([.stub(id: 1)])),
            progress: StubQuranProgressRepository(failure: QuranStubError())
        )

        await model.loadList()
        await model.loadProgress()

        #expect(model.listPhase != .unavailable)
        #expect(model.surahs.count == 1)
        #expect(model.bookmarks.isEmpty)
        #expect(model.lastRead == nil)
    }

    @Test func keepingAVerseMarksItAndStoresIt() async {
        let progress = StubQuranProgressRepository()
        let model = viewModel(StubQuranRepository(), progress: progress)

        await model.setBookmark(true, for: kursi)

        #expect(model.isBookmarked(kursi))
        #expect(progress.writes == [.added(kursi)])
    }

    @Test func forgettingAVerseUnmarksIt() async {
        let progress = StubQuranProgressRepository(
            bookmarks: [QuranBookmark(reference: kursi)]
        )
        let model = viewModel(StubQuranRepository(), progress: progress)

        await model.loadProgress()
        await model.setBookmark(false, for: kursi)

        #expect(model.isBookmarked(kursi) == false)
        #expect(model.bookmarks.isEmpty)
    }

    /// The screen moves first so the tap does not lag the finger; a failed write has to put it
    /// back, or the reader is left looking at a bookmark that was never saved.
    @Test func aFailedWriteRollsTheMarkBack() async {
        let model = viewModel(
            StubQuranRepository(),
            progress: StubQuranProgressRepository(failure: QuranStubError())
        )

        await model.setBookmark(true, for: kursi)

        #expect(model.isBookmarked(kursi) == false)
    }

    // MARK: Position

    @Test func savesTheLastVerseThatCameIntoView() async {
        let progress = StubQuranProgressRepository()
        let model = viewModel(StubQuranRepository(), progress: progress)

        model.noteVerseInView(VerseReference(surah: 2, verse: 100))
        model.noteVerseInView(kursi)
        model.saveReadingPosition()
        // `loadProgress()` waits on the write before it reads, which is the ordering under test.
        await model.loadProgress()

        #expect(progress.writes == [.recordedPosition(kursi)])
        #expect(model.lastRead?.reference == kursi)
    }

    /// Nothing seen means nothing to save. Without this guard, opening a chapter and leaving it
    /// before a single row appeared would write a stale position from a previous sitting.
    @Test func savesNothingWhenNoVerseHasAppeared() async {
        let progress = StubQuranProgressRepository()
        let model = viewModel(StubQuranRepository(), progress: progress)

        model.saveReadingPosition()
        await model.loadProgress()

        #expect(progress.writes.isEmpty)
    }

    /// Losing a position is not worth surfacing: the text is unaffected and the next sitting
    /// overwrites it. What matters is that it does not trap or leave a half-written state.
    @Test func aFailedPositionWriteIsSwallowed() async {
        let model = viewModel(
            StubQuranRepository(),
            progress: StubQuranProgressRepository(failure: QuranStubError())
        )

        model.noteVerseInView(kursi)
        model.saveReadingPosition()
        await model.loadProgress()

        #expect(model.lastRead == nil)
    }

    /// The bug this ordering exists for: leaving the reader writes the position while the list
    /// underneath re-reads it. Without the wait, the read lands first and "continue reading" goes
    /// on naming the verse the reader opened at rather than the one they reached.
    @Test func aPositionWrittenOnTheWayOutIsNotOvertakenByTheListReloading() async {
        let progress = StubQuranProgressRepository(
            position: ReadingPosition(reference: VerseReference(surah: 2, verse: 1))
        )
        let model = viewModel(StubQuranRepository(), progress: progress)

        model.noteVerseInView(kursi)
        model.saveReadingPosition()
        await model.loadProgress()

        #expect(model.lastRead?.reference == kursi)
    }

    // MARK: Search

    @Test func anEmptyFieldIsNotASearch() async {
        let model = viewModel(StubQuranRepository())
        model.searchText = "   "

        await model.search()

        #expect(model.searchPhase == .idle)
        #expect(!model.isSearching)
    }

    /// Punctuation alone folds to no tokens, so it is the same as an empty field rather than a
    /// search that finds nothing. The screen must not offer "no results" for a typed comma.
    @Test func punctuationAloneIsNotASearchEither() async {
        let model = viewModel(StubQuranRepository())
        model.searchText = "؟؟"

        await model.search()

        #expect(model.searchPhase == .idle)
    }

    @Test func aQueryWithResultsShowsThem() async {
        let results = QuranSearchResults(
            surahs: [.stub(id: 2)],
            verses: [.stub(surah: 2, number: 255)],
            totalVerseMatches: 1
        )
        let model = viewModel(StubQuranRepository(search: .success(results)))
        model.searchText = "الله"

        await model.search()

        #expect(model.searchPhase == .results(results))
        #expect(model.isSearching)
    }

    /// Found nothing is its own phase, and not the same as the corpus failing to answer — the
    /// reader is told "no such verse" rather than "the Quran could not be loaded".
    @Test func aQueryWithNoResultsIsEmptyRatherThanUnavailable() async {
        let model = viewModel(StubQuranRepository(search: .success(.none)))
        model.searchText = "زقزقة"

        await model.search()

        #expect(model.searchPhase == .empty)
    }

    @Test func aFailedSearchSaysSoRatherThanShowingNothingFound() async {
        let model = viewModel(StubQuranRepository(search: .failure(QuranStubError())))
        model.searchText = "الله"

        await model.search()

        #expect(model.searchPhase == .unavailable)
    }

    /// The folding happens once, in the view model, so the repository is handed a query rather
    /// than raw text — which is what lets the corpus be asked the same question every time
    /// regardless of how the reader spelled it.
    @Test func theRepositoryIsAskedForAFoldedQuery() async {
        let repository = StubQuranRepository(search: .success(.none))
        let model = viewModel(repository)
        model.searchText = "ٱلرَّحْمَٰنِ"

        await model.search()

        #expect(repository.requests.contains(.search(ArabicSearchQuery("الرحمن"))))
    }

    /// Cancellation is the debounce: `.task(id:)` cancels the previous run on the next keystroke,
    /// and a cancelled run must leave the phase alone rather than overwrite results that are
    /// still on screen. Here the task is cancelled before the sleep can finish.
    @Test func aCancelledSearchLeavesThePhaseUntouched() async {
        let model = viewModel(StubQuranRepository(search: .success(.none)))
        model.searchText = "الله"

        let task = Task { await model.search() }
        task.cancel()
        await task.value

        #expect(model.searchPhase == .idle)
    }

    @Test func openingAResultPutsTheSearchAway() async {
        let model = viewModel(StubQuranRepository(search: .success(.none)))
        model.searchText = "الله"
        await model.search()

        model.clearSearch()

        #expect(model.searchText.isEmpty)
        #expect(model.searchPhase == .idle)
        #expect(!model.isSearching)
    }
}

/// The helpers the reading screen draws its headings from.
///
/// Pure functions over a loaded span, which is why they are tested without a view model at all.
@MainActor
struct ReadingLayoutTests {

    private let alFatiha = Surah.stub(id: 1, verseCount: 7, bismillah: nil)
    private let alBaqara = Surah.stub(
        id: 2,
        arabicName: "البقرة",
        verseCount: 286,
        revelationPlace: .medinan,
        bismillah: "بِسْمِ ٱللَّهِ"
    )

    private func reading(_ verses: [Verse]) -> QuranViewModel.Reading {
        QuranViewModel.Reading(
            verses: verses,
            surahs: [1: alFatiha, 2: alBaqara]
        )
    }

    @Test func chaptersComeBackInTheOrderTheyAppearWithoutRepeating() {
        let loaded = reading([
            .stub(surah: 1, number: 6),
            .stub(surah: 1, number: 7),
            .stub(surah: 2, number: 1),
            .stub(surah: 2, number: 2)
        ])

        #expect(loaded.surahOrder == [1, 2])
    }

    @Test func aChaptersVersesAreOnlyTheOnesInThisSpan() {
        let loaded = reading([
            .stub(surah: 1, number: 7),
            .stub(surah: 2, number: 1),
            .stub(surah: 2, number: 2)
        ])

        #expect(loaded.verses(inSurah: 2).map(\.number) == [1, 2])
        #expect(loaded.verses(inSurah: 1).map(\.number) == [7])
    }

    @Test func theHeadingIsDrawnWhereTheChapterActuallyBegins() {
        let loaded = reading([.stub(surah: 2, number: 1), .stub(surah: 2, number: 2)])

        #expect(loaded.showsBismillah(forSurah: 2))
    }

    /// Juz 2 opens at 2:142. Printing the heading that belongs above 2:1 would tell the reader
    /// they are at the start of Al-Baqara when they are arriving in the middle of it.
    @Test func theHeadingIsNotDrawnWhenTheSpanStartsMidChapter() {
        let loaded = reading([.stub(surah: 2, number: 142), .stub(surah: 2, number: 143)])

        #expect(!loaded.showsBismillah(forSurah: 2))
    }

    /// Al-Fatiha's basmala is verse 1, so it has no heading to draw.
    @Test func aChapterWithNoHeadingNeverDrawsOne() {
        let loaded = reading([.stub(surah: 1, number: 1)])

        #expect(!loaded.showsBismillah(forSurah: 1))
    }

    // MARK: The flattened rows

    /// A single chapter draws no heading — the navigation title already names it. Taken from the
    /// middle of one, where there is no basmala either, the rows are the verses and nothing else.
    @Test func oneChapterFlattensToItsVersesAlone() {
        let loaded = reading([.stub(surah: 2, number: 142), .stub(surah: 2, number: 143)])

        #expect(loaded.items.count == 2)
        #expect(loaded.items.allSatisfy { if case .verse = $0 { true } else { false } })
    }

    /// Opening a chapter at its first verse still draws the basmala above it, heading or no
    /// heading — the two are separate questions.
    @Test func aChapterOpenedAtItsStartKeepsItsBasmala() {
        let loaded = reading([.stub(surah: 2, number: 1), .stub(surah: 2, number: 2)])

        #expect(loaded.items.first == .bismillah(2))
        #expect(!loaded.items.contains(.heading(2)))
    }

    /// A part crosses chapters, so each one is named where it starts.
    @Test func aSpanAcrossChaptersNamesEachOne() {
        let loaded = reading([.stub(surah: 1, number: 7), .stub(surah: 2, number: 1)])

        #expect(loaded.items.first == .heading(1))
        #expect(loaded.items.contains(.heading(2)))
    }

    /// The basmala belongs above the chapter's first verse and nowhere else — juz 2 opens at
    /// 2:142, and a heading there would claim the reader is at the start of Al-Baqara.
    @Test func theBasmalaIsARowOnlyWhereTheChapterActuallyBegins() {
        let opening = reading([.stub(surah: 2, number: 1)])
        let middle = reading([.stub(surah: 2, number: 142)])

        #expect(opening.items.contains(.bismillah(2)))
        #expect(!middle.items.contains(.bismillah(2)))
    }

    /// Every row needs a stable, distinct id: it is what `LazyVStack` diffs on and what
    /// `scrollTo` aims at.
    @Test func everyRowHasItsOwnIdentity() {
        let loaded = reading([.stub(surah: 1, number: 7), .stub(surah: 2, number: 1)])

        let ids = loaded.items.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    /// The rows must come out in reading order, or the mushaf is not the mushaf.
    @Test func versesKeepTheirOrder() {
        let loaded = reading([
            .stub(surah: 2, number: 1),
            .stub(surah: 2, number: 2),
            .stub(surah: 2, number: 3)
        ])

        let numbers = loaded.items.compactMap { item -> Int? in
            if case .verse(let verse) = item { verse.number } else { nil }
        }
        #expect(numbers == [1, 2, 3])
    }
}
