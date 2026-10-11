//
//  QuranSearchHighlightTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Mushaf's highlighting kept (Q4), on both texts the app can draw: Tanzil's Uthmani (the public
/// build) and QUL's KFGQPC Hafs (the full build). Highlighting re-folds each displayed word and
/// compares it with the query, so it has to work on either encoding of the same verse.
///
/// The index is over the imla'i spelling and the screen shows the Uthmani, so a word whose two
/// spellings fold apart is marked through a highlight-only reading of the dagger alef.
struct QuranSearchHighlightTests {

    static let databases = [QuranTestData.publicDatabase] + (QuranTestData.hasFullData ? [QuranTestData.fullDatabase] : [])

    private func text(of reference: VerseReference, in database: QuranDatabase) async throws -> String {
        let ayahs = try await QuranTestData.repository(database).ayahs(surah: reference.surah, style: .madaniV2)
        return try #require(ayahs.first { $0.id == reference }).text
    }

    private func highlighted(_ query: String, in text: String) throws -> [String] {
        let query = try #require(QuranSearchQuery(query, scope: .quran))
        return QuranSearchHighlight.arabicRanges(in: text, query: query).map { String(text[$0]) }
    }

    /// الرحمن in 1:3, once, whichever text is drawn.
    @Test(arguments: databases)
    func aSearchedWordIsMarkedInTheDisplayedText(_ database: QuranDatabase) async throws {
        let text = try await text(of: VerseReference(surah: 1, verse: 3), in: database)

        let marked = try highlighted("الرحمن", in: text)

        #expect(marked.count == 1)
        #expect(marked.allSatisfy { text.contains($0) })
    }

    /// Every word of a two-word query, in the verse's own spelling and nowhere else.
    @Test(arguments: databases)
    func everyWordOfTheQueryIsMarked(_ database: QuranDatabase) async throws {
        let text = try await text(of: VerseReference(surah: 1, verse: 2), in: database)

        let marked = try highlighted("الحمد لله", in: text)

        #expect(marked.count == 2)
    }

    /// A word found through its stem (للرحمن under الرحمن, 19:26) is marked too: the index found it
    /// that way, so the mark has to agree.
    @Test(arguments: databases)
    func aWordWithAnAttachedParticleIsMarked(_ database: QuranDatabase) async throws {
        let text = try await text(of: VerseReference(surah: 19, verse: 26), in: database)

        #expect(try highlighted("الرحمن", in: text).count == 1)
    }

    /// The highlight never invents a match: a query word not in the verse marks nothing.
    @Test(arguments: databases)
    func aWordNotInTheVerseMarksNothing(_ database: QuranDatabase) async throws {
        let text = try await text(of: VerseReference(surah: 112, verse: 1), in: database)

        #expect(try highlighted("فرعون", in: text).isEmpty)
    }

    /// The former gap, closed: السماوات finds 2:164 — the index is imla'i — and the Uthmani
    /// ٱلسَّمَٰوَٰتِ, which folds to السموت, is marked through the highlight-only dagger-alef reading.
    @Test(arguments: databases)
    func aWordSpelledDifferentlyInUthmaniIsFoundAndMarked(_ database: QuranDatabase) async throws {
        let verse = VerseReference(surah: 2, verse: 164)
        let query = try #require(QuranSearchQuery("السماوات", scope: .quran))
        let search = QuranSearchRepository(quran: database.corpus, store: ContentPackStore(directory: nil), index: QuranTestData.index(database))

        let found = try await search.searchQuran(query)
        let text = try await text(of: verse, in: database)

        #expect(found.exact.contains(verse))
        #expect(!QuranSearchHighlight.arabicRanges(in: text, query: query).isEmpty)
    }
}
