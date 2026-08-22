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

    // MARK: Search

    private func search(_ text: String, limit: Int = 100) async throws -> QuranSearchResults {
        try await repository.search(ArabicSearchQuery(text), limit: limit)
    }

    /// The test this whole slice exists for.
    ///
    /// Every one of these words is spelled in the mushaf without the alef a reader types —
    /// ٱلسَّمَٰوَٰتِ, ٱلصَّٰلِحَٰتِ, ٱلْكَٰفِرِينَ — so folding the *Uthmani* text would index `السموت`,
    /// `الصلحت`, `الكفرين` and find none of them. That is exactly what the corpus did until the
    /// search column was rebuilt from Tanzil's Simple Clean text, and it failed silently: the
    /// screen showed "no results" for words that are in the Quran hundreds of times.
    @Test(arguments: ["السماوات", "الصالحات", "الكافرين", "القيامة", "إبراهيم", "الملائكة"])
    func aWordSpelledWithAnAlefFindsTheVerseThatOmitsIt(word: String) async throws {
        #expect(try await search(word).verses.isEmpty == false)
    }

    @Test func aFragmentOfAVerseFindsThatVerseFirst() async throws {
        let results = try await search("قل هو الله أحد")

        #expect(results.verses.first?.id == VerseReference(surah: 112, verse: 1))
    }

    /// The prefix on the last word, which is what makes results arrive mid-word rather than only
    /// once a word is finished.
    @Test func aHalfTypedWordStillMatches() async throws {
        let results = try await search("إياك نعب")

        #expect(results.verses.map(\.id).contains(VerseReference(surah: 1, verse: 5)))
    }

    /// The fallback. These two words never sit together in a verse, so the phrase reading finds
    /// nothing and the keyword reading takes over — which is the difference between "no results"
    /// and the twelve verses that name them both.
    @Test func twoWordsThatNeverAdjoinAreStillFoundTogether() async throws {
        let results = try await search("موسى فرعون")

        #expect(results.verses.isEmpty == false)
        #expect(results.totalVerseMatches > 1)
    }

    /// The basmala is a *verse* exactly twice: 1:1, and 27:30, where Sulayman's letter opens with
    /// it. Everywhere else the mushaf prints it as an unnumbered heading, which the build lifts
    /// off verse 1 into `surah.bismillah` — and lifts off the search text the same way. Without
    /// that second cut this would be 114 hits: every chapter's first verse, each of them then
    /// drawn with text that does not contain the words that were searched for.
    @Test func theBasmalaIsAVerseTwiceAndAHeadingEverywhereElse() async throws {
        let results = try await search("بسم الله الرحمن الرحيم")

        #expect(results.totalVerseMatches == 2)
        #expect(
            results.verses.map(\.id) == [
                VerseReference(surah: 1, verse: 1),
                VerseReference(surah: 27, verse: 30),
            ]
        )
    }

    // MARK: Search — chapters

    @Test(arguments: [("البقرة", 2), ("Al-Baqara", 2), ("The Opening", 1), ("baqara", 2)])
    func aChapterIsFoundByAnyOfItsThreeNames(typed: String, number: Int) async throws {
        #expect(try await search(typed).surahs.map(\.id).contains(number))
    }

    /// The folding at work on a name: a reader typing the wrong final letter still finds it.
    @Test func aChapterNameFoundWithTaMarbutaWrittenAsHa() async throws {
        #expect(try await search("الفاتحه").surahs.map(\.id).contains(1))
    }

    // MARK: Search — shape of the answer

    @Test func theCapLimitsTheVersesButNotTheCount() async throws {
        let results = try await search("الله", limit: 10)

        #expect(results.verses.count == 10)
        #expect(results.totalVerseMatches > 10)
    }

    @Test func anEmptyQueryIsNotASearch() async throws {
        let results = try await search("   ")

        #expect(results == .none)
    }

    /// Nothing a reader can type is FTS5 syntax — see `ArabicSearchQuery`. A bare quote used to be
    /// a syntax error inside the database rather than an empty result.
    @Test(arguments: ["\"", "*", "NEAR(", "زقزقة"])
    func aQueryThatMatchesNothingComesBackEmptyRatherThanThrowing(typed: String) async throws {
        #expect(try await search(typed).verses.isEmpty)
    }
}
