//
//  QuranViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct QuranViewModelTests {

    private func viewModel(_ repository: StubQuranRepository) -> QuranViewModel {
        QuranViewModel(useCase: GetQuranUseCase(repository: repository))
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
}
