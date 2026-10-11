//
//  QuranLibraryIndexTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The Library's four indexes as row models (M5.2, design section 7).
///
/// The public build has no printed pages, so its rows carry none and its Library has no Page tab
/// (Q5). The full build adds the pages. Every page expected there is read from the corpus being
/// tested, never typed in from Mushaf's table: the layout is the data's to say, and a copied number
/// would only be right until the data changed. The structural counts (114 surahs, 30 juz, 60 hizb,
/// 240 quarters) are not layout, so they are literals.
struct QuranLibraryIndexTests {

    private func publicCorpus() async throws -> QuranCorpus {
        try await QuranTestData.repository(QuranTestData.publicDatabase).loadCorpus(style: .madaniV2)
    }

    private func fullCorpus() async throws -> QuranCorpus {
        try await QuranTestData.repository(QuranTestData.fullDatabase).loadCorpus(style: .madaniV2)
    }

    // MARK: The Tanzil build: no pages anywhere

    /// The case the task names: the fallback has no Page tab, and no page cell exists.
    @Test func theFallbackHidesThePageTab() async throws {
        let corpus = try await publicCorpus()
        let index = QuranLibraryIndex(corpus: corpus)

        #expect(!corpus.hasPages)
        #expect(index.tabs == [.surah, .juz, .hizb])
        #expect(!index.showsPages)
        #expect(index.pages.isEmpty)
        #expect(QuranLibraryIndex.tabs(showingPages: true) == [.surah, .juz, .hizb, .page])
        #expect(QuranLibraryIndex.tabs(showingPages: true).last == .page)
    }

    /// No row carries a page number: not a surah, a juz, a hizb or a quarter.
    @Test func noRowCarriesAPageInThePublicBuild() async throws {
        let corpus = try await publicCorpus()
        let index = QuranLibraryIndex(corpus: corpus)
        let quarters = index.hizb.flatMap { $0.quarters }

        #expect(index.surahs.allSatisfy { $0.startPage == nil })
        #expect(index.juz.allSatisfy { $0.page == nil })
        #expect(index.hizb.allSatisfy { $0.hizb.page == nil })
        #expect(quarters.allSatisfy { $0.page == nil })
    }

    /// The gate itself, not the data. The public database happens to hold no pages, so the test above
    /// would pass even if `QuranLibraryIndex.init` let a page through. This builds a corpus whose
    /// surahs and divisions carry their pages (the full corpus's own values) but whose `pages` are
    /// empty, so `hasPages` is false, and checks that no page reaches any row.
    ///
    /// `QuranCorpus`'s initialiser takes its surahs, ayahs, pages and metadata directly and derives
    /// `hasPages` from `pages.isEmpty`, so a copy with the pages removed is an ordinary value.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func aCorpusWithNoPagesShowsNoPageEvenWhereItsRowsHaveOne() async throws {
        let full = try await fullCorpus()
        // Preconditions: the values the gate has to hide really are there.
        try #require(full.hasPages)
        try #require(full.surahs.allSatisfy { $0.startPage != nil }, "every surah carries a start page")
        try #require(full.metadata.juz.allSatisfy { $0.page != nil }, "every juz carries a page")
        try #require(full.metadata.hizb.allSatisfy { $0.page != nil }, "every hizb carries a page")
        try #require(full.metadata.rub.allSatisfy { $0.page != nil }, "every quarter carries a page")

        let stripped = QuranCorpus(
            style: full.style,
            surahs: full.surahs,
            ayahs: full.ayahs,
            pages: [],
            metadata: full.metadata
        )
        try #require(!stripped.hasPages)
        let index = QuranLibraryIndex(corpus: stripped)

        #expect(!index.showsPages)
        #expect(index.tabs == [.surah, .juz, .hizb])
        #expect(index.pages.isEmpty)
        #expect(index.surahs.allSatisfy { $0.startPage == nil }, "the surahs keep their pages; the rows must not")
        #expect(index.juz.allSatisfy { $0.page == nil })
        #expect(index.hizb.allSatisfy { $0.hizb.page == nil })
        #expect(index.hizb.flatMap { $0.quarters }.allSatisfy { $0.page == nil })
    }

    /// The shape of each index: how many rows, which kinds, where each row goes, and that no two
    /// rows share an identifier. The surah rows keep the corpus's own surahs, in order.
    @Test func theTanzilRowsHaveTheRightCountsTargetsAndIds() async throws {
        let corpus = try await publicCorpus()
        let index = QuranLibraryIndex(corpus: corpus)

        #expect(index.surahs.count == 114)
        #expect(index.surahs.map(\.surah) == corpus.surahs)
        #expect(index.juz.count == 30)
        #expect(index.juz.map(\.number) == Array(1...30))
        #expect(index.hizb.count == 60)
        #expect(index.hizb.map { $0.hizb.number } == Array(1...60))

        let quarterKinds: [QuranLibraryStartRow.Kind] = [.quarter(1), .quarter(2), .quarter(3)]
        #expect(index.hizb.allSatisfy { $0.quarters.map(\.kind) == quarterKinds }, "each hizb has three quarters, of kinds 1, 2 and 3")

        let quarters = index.hizb.flatMap { $0.quarters }
        #expect(quarters.count == 180, "three quarters for each of the sixty hizb")
        #expect(quarters.allSatisfy { quarter in corpus.metadata.rub.contains { $0.ayah == quarter.ayah } },
                "every quarter sits on a rub start the corpus gives")

        #expect(index.juz.allSatisfy { $0.target == .juz($0.number) })
        #expect(index.hizb.allSatisfy { $0.hizb.target == .hizb($0.hizb.number) })
        #expect(quarters.allSatisfy { $0.target == .ayah($0.ayah) }, "a quarter goes to its ayah, not its hizb")

        let ids = index.juz.map(\.id) + index.hizb.map(\.id) + quarters.map(\.id)
        #expect(Set(ids).count == ids.count, "every division row has its own id")
        #expect(Set(index.surahs.map(\.id)).count == 114)
    }

    // MARK: The full build: four tabs and the printed layout

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func theFullBuildShowsFourTabsAndEveryPage() async throws {
        let corpus = try await fullCorpus()
        let index = QuranLibraryIndex(corpus: corpus)

        #expect(corpus.hasPages)
        #expect(index.showsPages)
        #expect(index.tabs == [.surah, .juz, .hizb, .page])
        #expect(index.pages.count == corpus.pages.count)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func theFullBuildRowsCarryTheCorporaPages() async throws {
        let corpus = try await fullCorpus()
        let index = QuranLibraryIndex(corpus: corpus)

        for row in index.surahs {
            #expect(row.startPage != nil, "surah \(row.surah.number)")
            #expect(row.startPage == corpus.surah(row.surah.number)?.startPage, "surah \(row.surah.number)")
        }

        for row in index.juz {
            let start = try #require(corpus.metadata.juz.first { $0.number == row.number })
            #expect(row.page == start.page, "juz \(row.number)")
        }

        for hizb in index.hizb {
            let start = try #require(corpus.metadata.hizb.first { $0.number == hizb.hizb.number })
            #expect(hizb.hizb.page == start.page, "hizb \(hizb.hizb.number)")
            for quarter in hizb.quarters {
                let rub = try #require(corpus.metadata.rub.first { $0.ayah == quarter.ayah })
                #expect(quarter.page == rub.page, "quarter \(quarter.id)")
            }
        }

        for cell in index.pages {
            let page = try #require(corpus.page(cell.number))
            #expect(cell.surah?.number == page.firstAyah?.surah, "page \(cell.number) is in its first ayah's surah")
        }
    }

    /// Ported from Mushaf's `everyJuzOpensAtItsPage`, with its literal page table dropped: every juz
    /// opens on the page the corpus's metadata gives it, and that page holds the ayah the reader lands
    /// on. Guarded, because the pages are the full data's.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    @MainActor
    func everyJuzOpensAtItsPage() async throws {
        let settings = QuranReaderSettings(settingsStore: InMemorySettingsStore())
        let reader = QuranReaderViewModel(
            repository: QuranTestData.repository(QuranTestData.fullDatabase),
            settings: settings,
            allowsImmersive: false
        )
        await reader.load()
        reader.setDisplayMode(.mushaf)
        let corpus = try #require(reader.corpus)
        #expect(corpus.metadata.juz.count == 30)

        for number in 1...30 {
            let start = try #require(corpus.metadata.juz.first { $0.number == number })
            let page = try #require(start.page, "juz \(number) has a page in the full build")

            reader.open(.juz(number))

            #expect(reader.mushaf.page == page, "juz \(number) opens on its page")
            #expect(corpus.page(page)?.ayahs.contains(reader.location) == true, "juz \(number) starts on its page")
        }
    }

    // MARK: Both builds

    /// Each hizb begins on every fourth quarter, and each juz on every second hizb. The divisions are
    /// in both databases, so the check runs over both.
    @Test(arguments: [QuranTestData.publicDatabase] + (QuranTestData.hasFullData ? [QuranTestData.fullDatabase] : []))
    func hizbStartsAreEveryOtherQuarter(_ database: QuranDatabase) async throws {
        let metadata = try await QuranTestData.repository(database).loadCorpus(style: .madaniV2).metadata
        #expect(metadata.hizb.count == 60)
        #expect(metadata.rub.count == 240)
        for hizb in metadata.hizb {
            let quarter = (hizb.number - 1) * 4
            #expect(metadata.rub.indices.contains(quarter) && metadata.rub[quarter].ayah == hizb.ayah, "hizb \(hizb.number)")
        }
        // Every juz is two hizbs.
        for juz in metadata.juz {
            let hizb = (juz.number - 1) * 2
            #expect(metadata.hizb.indices.contains(hizb) && metadata.hizb[hizb].ayah == juz.ayah, "juz \(juz.number)")
        }
    }

    /// `make(from:)` is the same index as `init(corpus:)`, built off the main actor.
    @Test(arguments: [QuranTestData.publicDatabase] + (QuranTestData.hasFullData ? [QuranTestData.fullDatabase] : []))
    func theAsyncBuildAgreesWithTheSynchronousOne(_ database: QuranDatabase) async throws {
        let corpus = try await QuranTestData.repository(database).loadCorpus(style: .madaniV2)

        let built = await QuranLibraryIndex.make(from: corpus)

        #expect(built == QuranLibraryIndex(corpus: corpus))
    }
}
