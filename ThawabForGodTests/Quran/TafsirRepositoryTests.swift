//
//  TafsirRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Reads the commentary that actually ships.
///
/// The weight `QuranRepositoryTests` carries, for the same reason: the shape is fixed and
/// checkable. One edition, 6,010 notes, 226 verses passed over, and every note keyed to a verse
/// that exists — a build that disagrees with any of those is wrong in a way no amount of reading
/// the screen would reveal.
struct TafsirRepositoryTests {

    private let repository = TafsirRepository(database: CorpusDatabase(name: "tafsir"))

    private let jalalayn = "jalalayn"

    // MARK: The edition

    @Test func theBundleCarriesOneEdition() async throws {
        #expect(try await repository.editions().count == 1)
    }

    @Test func itIsAlJalalaynInArabic() async throws {
        let edition = try #require(try await repository.editions().first)

        #expect(edition.id == jalalayn)
        #expect(edition.language == .arabic)
        #expect(edition.arabicName == "تفسير الجلالين")
    }

    /// The licence travels with the data because it is *shown*. A reader is entitled to know on
    /// what footing a five-century-old commentary arrived in their app.
    @Test func theEditionSaysWhyItMayBeHere() async throws {
        let edition = try #require(try await repository.editions().first)

        #expect(edition.licence.contains("Public domain"))
        #expect(!edition.arabicAuthor.isEmpty)
        #expect(!edition.englishAuthor.isEmpty)
    }

    // MARK: The notes

    @Test func aVerseWithANoteHasOne() async throws {
        let note = try await repository.note(
            for: VerseReference(surah: 2, verse: 255),
            in: jalalayn
        )

        #expect(note != nil)
        #expect(note?.reference == VerseReference(surah: 2, verse: 255))
        #expect(note?.edition.id == jalalayn)
    }

    /// Al-Jalalayn quotes the words it is glossing between ornate parentheses, which is what makes
    /// it readable beside the verse rather than as an essay about it.
    @Test func aNoteQuotesTheWordsItGlosses() async throws {
        let note = try #require(
            try await repository.note(for: VerseReference(surah: 112, verse: 1), in: jalalayn)
        )

        #expect(note.text.contains("﴿"))
        #expect(note.text.contains("﴾"))
    }

    /// The heart of this slice. The two Jalals pass over the plain formulas, and *no row* is the
    /// honest record of that — not an empty string, and above all not the note belonging to the
    /// verse above, which would print a gloss of one verse under another.
    @Test(arguments: [(2, 82), (2, 274), (2, 277), (3, 2), (5, 10)])
    func averseTheCommentaryPassesOverHasNoNote(surah: Int, verse: Int) async throws {
        let note = try await repository.note(
            for: VerseReference(surah: surah, verse: verse),
            in: jalalayn
        )

        #expect(note == nil)
    }

    @Test func exactlyTwoHundredAndTwentySixVersesArePassedOver() async throws {
        let quran = QuranRepository(database: CorpusDatabase(name: "quran"))
        var silent = 0

        for surah in try await quran.surahs() {
            for verse in try await quran.verses(inSurah: surah.id) {
                if try await repository.note(for: verse.id, in: jalalayn) == nil {
                    silent += 1
                }
            }
        }

        #expect(silent == 226)
    }

    // MARK: Absence

    @Test func anUnknownEditionHasNoNoteRatherThanFailing() async throws {
        #expect(
            try await repository.note(
                for: VerseReference(surah: 1, verse: 1),
                in: "no-such-edition"
            ) == nil
        )
    }

    @Test func aVerseTheMushafDoesNotHaveHasNoNote() async throws {
        #expect(
            try await repository.note(for: VerseReference(surah: 115, verse: 1), in: jalalayn) == nil
        )
    }
}
