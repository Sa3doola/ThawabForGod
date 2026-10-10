//
//  QuranReaderPlaceTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Where a `GoToTarget` lands in the corpus (M5.1, design section 3.3).
///
/// The Tanzil build has no printed pages, so a page never resolves there, and a surah, an ayah or a
/// division resolves to its ayah with no page. The full build adds the page each one sits on. Every
/// expected page and every juz or hizb start is read from the corpus being tested, not typed in: the
/// layout is the data's to say, and a copied number would only be right until the data changed.
struct QuranReaderPlaceTests {

    private func publicCorpus() async throws -> QuranCorpus {
        try await QuranTestData.repository(QuranTestData.publicDatabase).loadCorpus(style: .madaniV2)
    }

    private func fullCorpus() async throws -> QuranCorpus {
        try await QuranTestData.repository(QuranTestData.fullDatabase).loadCorpus(style: .madaniV2)
    }

    // MARK: The Tanzil build: text and divisions, no pages

    @Test func aSurahLandsOnItsFirstAyahWithNoPage() async throws {
        let corpus = try await publicCorpus()
        #expect(!corpus.hasPages)

        let place = try #require(QuranReaderPlace.resolve(.surah(2), in: corpus))

        #expect(place == QuranReaderPlace(ayah: VerseReference(surah: 2, verse: 1), page: nil, selectsAyah: false))
    }

    @Test func anAyahSelectsItselfAndHasNoPage() async throws {
        let corpus = try await publicCorpus()
        let reference = VerseReference(surah: 2, verse: 255)

        let place = try #require(QuranReaderPlace.resolve(.ayah(reference), in: corpus))

        #expect(place == QuranReaderPlace(ayah: reference, page: nil, selectsAyah: true))
    }

    @Test func aJuzLandsOnTheStartAyahTheCorpusGivesIt() async throws {
        let corpus = try await publicCorpus()
        let start = try #require(corpus.metadata.juz.first { $0.number == 30 })

        let place = try #require(QuranReaderPlace.resolve(.juz(30), in: corpus))

        #expect(place == QuranReaderPlace(ayah: start.ayah, page: nil, selectsAyah: false))
    }

    @Test func aHizbLandsOnTheStartAyahTheCorpusGivesIt() async throws {
        let corpus = try await publicCorpus()
        let start = try #require(corpus.metadata.hizb.first { $0.number == 60 })

        let place = try #require(QuranReaderPlace.resolve(.hizb(60), in: corpus))

        #expect(place == QuranReaderPlace(ayah: start.ayah, page: nil, selectsAyah: false))
    }

    /// A Tanzil page number is not a V2 page number (MAPPING T4 and Q5), so no page target resolves
    /// in this build, whatever the number.
    @Test func noPageResolvesInTheTanzilBuild() async throws {
        let corpus = try await publicCorpus()
        for number in [1, 50, 604] {
            #expect(QuranReaderPlace.resolve(.page(number), in: corpus) == nil, "page \(number)")
        }
    }

    /// Each of these is outside the corpus, so the reader stays where it is.
    @Test func targetsOutsideTheCorpusResolveToNothing() async throws {
        let corpus = try await publicCorpus()
        #expect(QuranReaderPlace.resolve(.ayah(VerseReference(surah: 2, verse: 287)), in: corpus) == nil)
        #expect(QuranReaderPlace.resolve(.surah(115), in: corpus) == nil)
        #expect(QuranReaderPlace.resolve(.juz(31), in: corpus) == nil)
        #expect(QuranReaderPlace.resolve(.hizb(61), in: corpus) == nil)
    }

    // MARK: The full build: the printed layout

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func aPageLandsOnItsFirstAyah() async throws {
        let corpus = try await fullCorpus()
        let page = try #require(corpus.page(50))

        let place = try #require(QuranReaderPlace.resolve(.page(50), in: corpus))

        #expect(place.page == 50)
        #expect(place.ayah == page.firstAyah)
        #expect(!place.selectsAyah)
        #expect(corpus.pageNumber(for: place.ayah) == 50)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func aPageBeyondTheMushafResolvesToNothing() async throws {
        let corpus = try await fullCorpus()
        #expect(QuranReaderPlace.resolve(.page(corpus.pages.count + 1), in: corpus) == nil)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func anAyahCarriesThePageItStartsOn() async throws {
        let corpus = try await fullCorpus()
        let reference = VerseReference(surah: 2, verse: 255)

        let place = try #require(QuranReaderPlace.resolve(.ayah(reference), in: corpus))

        #expect(place.ayah == reference)
        #expect(place.selectsAyah)
        let page = try #require(place.page)
        #expect(page == corpus.ayah(reference)?.page)
        #expect(corpus.page(page)?.ayahs.contains(reference) == true)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func aSurahLandsOnItsStartPage() async throws {
        let corpus = try await fullCorpus()
        let surah = try #require(corpus.surah(18))

        let place = try #require(QuranReaderPlace.resolve(.surah(18), in: corpus))

        #expect(place.ayah == VerseReference(surah: 18, verse: 1))
        #expect(place.page == surah.startPage)
        #expect(place.page != nil)
        #expect(!place.selectsAyah)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func aJuzLandsOnItsStartAyahAndPage() async throws {
        let corpus = try await fullCorpus()
        let start = try #require(corpus.metadata.juz.first { $0.number == 5 })

        let place = try #require(QuranReaderPlace.resolve(.juz(5), in: corpus))

        #expect(place == QuranReaderPlace(ayah: start.ayah, page: start.page, selectsAyah: false))
    }
}
