//
//  QuranRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The Quran repository read against the bundled database: the text, the chapters, the divisions
/// and the printed pages, and what it says when the database is missing.
///
/// The chapter count, verse count, a verse's juz and a chapter's verses are the same in both
/// builds, so those run on each bundled database. Everything that names a page, a line or a word
/// is the printed layout, which only the full build carries (T4), so it is guarded to that build.
struct QuranRepositoryTests {

    let repository = QuranTestData.repository()

    @Test(arguments: [QuranTestData.publicDatabase] + (QuranTestData.hasFullData ? [QuranTestData.fullDatabase] : []))
    func corpusHasEveryVerseAndItsJuz(_ database: QuranDatabase) async throws {
        let corpus = try await QuranTestData.repository(database).loadCorpus(style: .madaniV2)
        #expect(corpus.surahs.count == 114)
        #expect(corpus.ayahs.count == 6236)
        #expect(corpus.ayah(VerseReference(surah: 2, verse: 255))?.juz == 3)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func corpusMatchesTheMushaf() async throws {
        let corpus = try await repository.loadCorpus(style: .madaniV2)
        #expect(corpus.pages.map(\.number) == Array(MushafStyle.madaniV2.pages))
        #expect(corpus.pages.flatMap(\.lines).count == 9046)
        #expect(corpus.surah(2)?.startPage == 2)
        #expect(corpus.ayah(VerseReference(surah: 18, verse: 1))?.page == 293)
        // 2:142 opens juz 2 on page 22.
        #expect(corpus.page(22)?.juz == 2)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func pageMatchesTheCorpusPage() async throws {
        let corpus = try await repository.loadCorpus(style: .madaniV2)
        for number in [1, 2, 7, 50, 76, 201, 604] {
            #expect(try await repository.page(number, style: .madaniV2) == corpus.page(number), "page \(number)")
        }
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func pageOneIsAlFatihahOnEightLines() async throws {
        let page = try await repository.page(1, style: .madaniV2)
        #expect(page.lines.count == 8)
        #expect(page.lines.first?.kind == .surahHeader(1))
        #expect(page.ayahs == (1...7).map { VerseReference(surah: 1, verse: $0) })
    }

    /// 2:45's end marker wraps to the start of page 7, line 12 (QUL layout).
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func wrappedMarkerOpensALine() async throws {
        let line = try #require(try await repository.page(7, style: .madaniV2).lines.first { $0.number == 12 })
        let first = try #require(line.segments.first)
        #expect(first.reference == VerseReference(surah: 2, verse: 45) && first.words.isEmpty && first.endsAyah)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func headerAtThePageBottom() async throws {
        let page = try await repository.page(76, style: .madaniV2)
        #expect(page.lines.last?.kind == .surahHeader(4))
        #expect(try await repository.page(77, style: .madaniV2).lines.first?.kind == .basmala)
    }

    @Test(arguments: [QuranTestData.publicDatabase] + (QuranTestData.hasFullData ? [QuranTestData.fullDatabase] : []))
    func surahsAndAyahsOfAChapter(_ database: QuranDatabase) async throws {
        let reader = QuranTestData.repository(database)
        let surahs = try await reader.surahs(style: .madaniV2)
        #expect(surahs.count == 114)
        let kahf = try await reader.ayahs(surah: 18, style: .madaniV2)
        #expect(kahf.count == 110)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func surahsStartOnTheirPages() async throws {
        let surahs = try await repository.surahs(style: .madaniV2)
        #expect(surahs[17].englishName == "Al-Kahf" && surahs[17].startPage == 293)
        let kahf = try await repository.ayahs(surah: 18, style: .madaniV2)
        #expect(kahf.first?.page == 293 && kahf.last?.page == 304)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func pageNumberForAyah() async throws {
        #expect(try await repository.pageNumber(for: VerseReference(surah: 2, verse: 255), style: .madaniV2) == 42)
        #expect(try await repository.pageNumber(for: VerseReference(surah: 114, verse: 1), style: .madaniV2) == 604)
        await #expect(throws: QuranDataError.self) { try await repository.pageNumber(for: VerseReference(surah: 1, verse: 8), style: .madaniV2) }
    }

    /// Juz, hizb and quarter starts and sajdahs. The counts are checked on the full build only, the
    /// one whose divisions were built from the printed markers (the text-only build derives its own).
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func metadata() async throws {
        let metadata = try await repository.metadata(style: .madaniV2)
        #expect(metadata.juz.count == 30 && metadata.hizb.count == 60 && metadata.rub.count == 240)
        #expect(metadata.sajdahs.count == 15 && metadata.sajdahs.filter(\.isRequired).count == 4)
        #expect(metadata.juz[10] == QuranMetadata.Start(number: 11, page: 201, ayah: VerseReference(surah: 9, verse: 93)))
        #expect(metadata.sajdahs.contains { $0.ayah == VerseReference(surah: 17, verse: 109) && $0.page == 293 })
    }

    @Test func missingDatabaseFailsToLoad() async {
        let missing = QuranRepository(database: CorpusDatabase(name: "does-not-exist"))
        await #expect(throws: CorpusDatabaseError.self) { try await missing.loadCorpus(style: .madaniV2) }
    }
}
