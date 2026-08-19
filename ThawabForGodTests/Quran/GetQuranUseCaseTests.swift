//
//  GetQuranUseCaseTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The use case is a pass-through, so what is worth pinning is that it passes the *right* thing
/// through — a chapter number and a part number are both small integers, and sending one where
/// the other belongs is the mistake this feature can make without crashing.
struct GetQuranUseCaseTests {

    @Test func chaptersComeStraightFromTheRepository() async throws {
        let expected = [Surah.stub(id: 1), Surah.stub(id: 2)]
        let useCase = GetQuranUseCase(repository: StubQuranRepository(surahs: .success(expected)))

        #expect(try await useCase.surahs() == expected)
    }

    @Test func readingAChapterAsksForThatChapter() async throws {
        let repository = StubQuranRepository()
        let useCase = GetQuranUseCase(repository: repository)

        _ = try await useCase.verses(inSurah: 36)

        #expect(repository.requests == [.versesInSurah(36)])
    }

    /// The one confusion worth a test of its own: part 30 must not be read as chapter 30.
    @Test func readingAPartAsksForThatPart() async throws {
        let repository = StubQuranRepository()
        let useCase = GetQuranUseCase(repository: repository)

        _ = try await useCase.verses(inJuz: 30)

        #expect(repository.requests == [.versesInJuz(30)])
    }

    @Test func anUnknownChapterIsNilRatherThanAFailure() async throws {
        let useCase = GetQuranUseCase(
            repository: StubQuranRepository(surahs: .success([.stub(id: 1)]))
        )

        #expect(try await useCase.surah(115) == nil)
    }

    @Test func aFailureIsPropagatedRatherThanSwallowed() async {
        let useCase = GetQuranUseCase(
            repository: StubQuranRepository(surahs: .failure(QuranStubError()))
        )

        await #expect(throws: QuranStubError.self) {
            try await useCase.surahs()
        }
    }
}

/// The corpus rows become domain values.
///
/// Built from hand-made records — the row-to-record half is covered end to end by
/// `QuranRepositoryTests` against the real bundle, and reaching a GRDB `Row` directly would mean
/// linking GRDB into the test target for no gain.
struct QuranMappingTests {

    @Test func aChapterCarriesItsThreeNamesAndItsPlace() throws {
        let record = SurahRecord(
            id: 2,
            arabicName: "البقرة",
            transliteration: "Al-Baqara",
            englishName: "The Cow",
            verseCount: 286,
            revelationPlace: "medinan",
            revelationOrder: 87,
            bismillah: "بِسْمِ ٱللَّهِ"
        )

        let surah = try #require(record.domainValue)

        #expect(surah.id == 2)
        #expect(surah.arabicName == "البقرة")
        #expect(surah.revelationPlace == .medinan)
        #expect(surah.verseCount == 286)
        #expect(surah.bismillah == "بِسْمِ ٱللَّهِ")
    }

    /// A chapter is dropped rather than defaulted. Guessing "Meccan" because the string did not
    /// parse would put a claim about revelation on screen that no source made.
    @Test func aChapterWithAnUnknownRevelationPlaceIsDropped() {
        let record = SurahRecord(
            id: 2,
            arabicName: "البقرة",
            transliteration: "Al-Baqara",
            englishName: "The Cow",
            verseCount: 286,
            revelationPlace: "martian",
            revelationOrder: 87,
            bismillah: nil
        )

        #expect(record.domainValue == nil)
    }

    @Test func averseCarriesItsDivisions() {
        let record = VerseRecord(
            surahNumber: 2,
            number: 255,
            text: "ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ",
            juz: 3,
            hizb: 5,
            rubElHizb: 17,
            page: 42,
            sajda: nil
        )

        let verse = record.domainValue

        #expect(verse.id == VerseReference(surah: 2, verse: 255))
        #expect(verse.juz == 3)
        #expect(verse.hizb == 5)
        #expect(verse.rubElHizb == 17)
        #expect(verse.page == 42)
        #expect(verse.sajda == nil)
    }

    @Test(arguments: [("obligatory", Sajda.obligatory), ("recommended", Sajda.recommended)])
    func aProstrationIsReadAsItsKind(stored: String, expected: Sajda) {
        let record = VerseRecord(
            surahNumber: 32, number: 15, text: "…",
            juz: 21, hizb: 42, rubElHizb: 165, page: 416, sajda: stored
        )

        #expect(record.domainValue.sajda == expected)
    }

    /// The opposite call from an unknown revelation place: a verse whose prostration mark this
    /// build does not understand is still the verse, and dropping it would take the text away
    /// over a marginal note about it.
    @Test func anUnknownProstrationKindReadsAsNoneRatherThanDroppingTheVerse() {
        let record = VerseRecord(
            surahNumber: 32, number: 15, text: "…",
            juz: 21, hizb: 42, rubElHizb: 165, page: 416, sajda: "encouraged"
        )

        #expect(record.domainValue.sajda == nil)
        #expect(record.domainValue.text == "…")
    }

    @Test func aPartCarriesItsRangeAsTwoReferences() {
        let record = JuzRecord(number: 2, startSurah: 2, startVerse: 142, endSurah: 2, endVerse: 252)

        #expect(record.domainValue.start == VerseReference(surah: 2, verse: 142))
        #expect(record.domainValue.end == VerseReference(surah: 2, verse: 252))
    }
}

/// A verse address orders the way the mushaf does.
struct VerseReferenceTests {

    @Test func chapterOutranksVerseInReadingOrder() {
        #expect(VerseReference(surah: 2, verse: 1) > VerseReference(surah: 1, verse: 7))
        #expect(VerseReference(surah: 2, verse: 1) < VerseReference(surah: 2, verse: 2))
    }

    @Test func itDescribesItselfAsAReference() {
        #expect(VerseReference(surah: 2, verse: 255).description == "2:255")
    }
}
