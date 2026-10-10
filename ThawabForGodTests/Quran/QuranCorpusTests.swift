//
//  QuranCorpusTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The whole Quran loaded as one corpus, and what the go-to field makes of what a reader types.
///
/// The chapter and verse counts are the same in both builds, so they run on each database that is
/// bundled: the Tanzil text in every clone, and the printed pages where the full data was built.
/// Page numbers exist only in the full build (T4), so anything that names one is guarded. The
/// go-to parsing runs on the preferred database: its page cases need pages, and the rest need only
/// the text.
struct QuranCorpusTests {

    @Test(arguments: [QuranTestData.publicDatabase] + (QuranTestData.hasFullData ? [QuranTestData.fullDatabase] : []))
    func bundledCorpusIsComplete(_ database: QuranDatabase) async throws {
        let corpus = try await QuranTestData.repository(database).loadCorpus(style: .madaniV2)
        #expect(corpus.surahs.count == 114)
        #expect(corpus.ayahs.count == 6236)
    }

    /// The printed layout: one page per Mushaf page, 2:255 on page 42, and An-Nas on the last.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func bundledCorpusHasItsPrintedPages() async throws {
        let corpus = try await QuranTestData.repository(QuranTestData.fullDatabase).loadCorpus(style: .madaniV2)
        #expect(corpus.pages.count == corpus.style.pageCount)
        #expect(corpus.ayah(VerseReference(surah: 2, verse: 255))?.page == 42)
        #expect(corpus.surah(114)?.startPage == 604)
    }

    @Test(arguments: [
        ("2:255", GoToTarget.ayah(VerseReference(surah: 2, verse: 255))),
        ("١١٤:٦", .ayah(VerseReference(surah: 114, verse: 6))),
    ])
    func goToParsesValidAyahs(text: String, expected: GoToTarget) async throws {
        let corpus = try await QuranTestData.repository().loadCorpus(style: .madaniV2)
        #expect(GoToTarget.parse(text, in: corpus) == expected)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason), arguments: [
        ("50", GoToTarget.page(50)),
        ("٥٠", .page(50)),
    ])
    func goToParsesValidPages(text: String, expected: GoToTarget) async throws {
        let corpus = try await QuranTestData.repository().loadCorpus(style: .madaniV2)
        #expect(GoToTarget.parse(text, in: corpus) == expected)
    }

    /// Every one of these is outside the corpus on either build: no such page, no such verse, or
    /// not a reference at all. In the text-only build every page is outside it (Q5).
    @Test(arguments: ["0", "605", "1:8", "115:1", "2:287", "page"])
    func goToRejectsTargetsOutsideTheCorpus(_ text: String) async throws {
        let corpus = try await QuranTestData.repository().loadCorpus(style: .madaniV2)
        #expect(GoToTarget.parse(text, in: corpus) == nil)
    }
}
