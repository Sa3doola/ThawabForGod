//
//  QuranRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Reads the corpus that actually ships.
///
/// This suite carries the weight `NamesRepositoryTests` does, for the same reason: the shape of
/// the mushaf is *fixed and checkable*. There are 114 chapters, 6,236 verses, 30 parts and 15
/// verses of prostration, and a build that disagrees with any of those is wrong in a way no
/// amount of reading the screen would reveal.
struct QuranRepositoryTests {

    private let repository = QuranRepository(database: CorpusDatabase(name: "quran"))

    // MARK: Shape

    @Test func thereAreExactlyOneHundredAndFourteenChapters() async throws {
        #expect(try await repository.surahs().count == 114)
    }

    @Test func theyAreNumberedOneThroughOneHundredAndFourteenInOrder() async throws {
        #expect(try await repository.surahs().map(\.id) == Array(1...114))
    }

    /// The count on the chapter and the verses actually stored must agree. They come from two
    /// different upstream files, and a disagreement is a chapter silently missing its end.
    @Test func everyChapterHasAsManyVersesAsItClaims() async throws {
        for surah in try await repository.surahs() {
            let verses = try await repository.verses(inSurah: surah.id)

            #expect(
                verses.count == surah.verseCount,
                "surah \(surah.id) claims \(surah.verseCount) verses, the corpus has \(verses.count)"
            )
            #expect(verses.map(\.number) == Array(1...surah.verseCount))
        }
    }

    @Test func theWholeMushafIsSixThousandTwoHundredAndThirtySixVerses() async throws {
        var total = 0
        for surah in try await repository.surahs() {
            total += try await repository.verses(inSurah: surah.id).count
        }

        #expect(total == 6236)
    }

    // MARK: Text

    @Test func everyVerseHasText() async throws {
        for surah in try await repository.surahs() {
            for verse in try await repository.verses(inSurah: surah.id) {
                #expect(!verse.text.isEmpty, "\(verse.id) has no text")
            }
        }
    }

    /// Al-Fatiha's basmala *is* its first verse, and At-Tawba has none. Every other chapter
    /// carries it as a heading lifted off verse 1 by the build script — so a chapter that lost
    /// its heading, or gained one it should not have, shows up here.
    @Test func onlyTwoChaptersHaveNoBismillahHeading() async throws {
        let without = try await repository.surahs()
            .filter { $0.bismillah == nil }
            .map(\.id)

        #expect(without == [1, 9])
    }

    /// The basmala having been lifted off, verse 1 of those chapters must be what remained —
    /// not the basmala repeated, and not an empty string.
    @Test func theBasmalaWasRemovedFromTheVerseItPrefixed() async throws {
        let bismillah = try #require(try await repository.surah(2)?.bismillah)
        let opening = try #require(try await repository.verses(inSurah: 2).first)

        #expect(!opening.text.isEmpty)
        #expect(opening.text != bismillah)
        #expect(!opening.text.hasPrefix(bismillah))
    }

    // MARK: Divisions

    @Test func thereAreThirtyPartsInOrder() async throws {
        #expect(try await repository.juzList().map(\.number) == Array(1...30))
    }

    /// The canonical boundaries. If the metadata is ever re-sourced, these are the four that say
    /// whether the new file means the same thing as the old one.
    @Test(arguments: [
        (1, VerseReference(surah: 1, verse: 1), VerseReference(surah: 2, verse: 141)),
        (2, VerseReference(surah: 2, verse: 142), VerseReference(surah: 2, verse: 252)),
        (23, VerseReference(surah: 36, verse: 28), VerseReference(surah: 39, verse: 31)),
        (30, VerseReference(surah: 78, verse: 1), VerseReference(surah: 114, verse: 6))
    ])
    func partsBeginAndEndWhereTheMushafSaysTheyDo(
        number: Int, start: VerseReference, end: VerseReference
    ) async throws {
        let juz = try #require(try await repository.juzList().first { $0.number == number })

        #expect(juz.start == start)
        #expect(juz.end == end)
    }

    /// A part read as a span must match the range the part claims — the two come from different
    /// columns, and this is what says they agree.
    @Test func aPartsVersesRunFromItsFirstReferenceToItsLast() async throws {
        for juz in try await repository.juzList() {
            let verses = try await repository.verses(inJuz: juz.number)

            #expect(verses.first?.id == juz.start, "juz \(juz.number) starts elsewhere")
            #expect(verses.last?.id == juz.end, "juz \(juz.number) ends elsewhere")
        }
    }

    /// Reading by part is the whole reason the division exists, so no part may be empty and the
    /// thirty together must be the whole mushaf with nothing counted twice.
    @Test func thePartsCoverTheWholeMushafExactlyOnce() async throws {
        var seen: [VerseReference] = []

        for juz in try await repository.juzList() {
            let verses = try await repository.verses(inJuz: juz.number)
            #expect(!verses.isEmpty, "juz \(juz.number) is empty")
            seen.append(contentsOf: verses.map(\.id))
        }

        #expect(seen.count == 6236)
        #expect(Set(seen).count == 6236)
    }

    @Test func aPartCrossesChapterBoundaries() async throws {
        // Juz 30 runs from An-Naba to the end — thirty-seven chapters in one part, which is what
        // makes the reading screen's chapter headings necessary rather than decorative.
        let chapters = Set(try await repository.verses(inJuz: 30).map(\.surahNumber))

        #expect(chapters.count == 37)
    }

    // MARK: Prostrations

    @Test func thereAreFifteenVersesOfProstration() async throws {
        var marked: [VerseReference] = []

        for surah in try await repository.surahs() {
            let verses = try await repository.verses(inSurah: surah.id)
            marked.append(contentsOf: verses.filter { $0.sajda != nil }.map(\.id))
        }

        #expect(marked.count == 15)
        #expect(marked.contains(VerseReference(surah: 7, verse: 206)))
        #expect(marked.contains(VerseReference(surah: 96, verse: 19)))
    }

    // MARK: Absence

    @Test func anUnknownChapterIsNilRatherThanAFailure() async throws {
        #expect(try await repository.surah(115) == nil)
    }

    @Test func anUnknownChapterHasNoVersesRatherThanFailing() async throws {
        #expect(try await repository.verses(inSurah: 115).isEmpty)
    }
}
