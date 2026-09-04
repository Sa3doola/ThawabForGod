//
//  AdhkarRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Reads the database that actually ships, not a fixture.
///
/// That is the point of this suite. Everything above the repository is tested against stubs and
/// would go on passing if `corpus.sqlite` were dropped from the bundle, renamed, or rebuilt with
/// a column missing — so this is the only thing standing between a packaging or schema mistake
/// and a screen that says the adhkar could not be loaded. It also exercises the records'
/// `init(row:)`, which nothing else can reach without linking GRDB into the test target.
struct AdhkarRepositoryTests {

    private let repository = AdhkarRepository(database: CorpusDatabase(name: "corpus"))

    // MARK: The shape of the book

    /// Hisn al-Muslim's 132 chapters, all of them, with the book's own order preserved inside
    /// each group.
    ///
    /// The number is asserted rather than described, because the failure it guards against is a
    /// build script that quietly dropped chapters: 130 chapters is a corpus nobody would notice
    /// was wrong by looking at the screen.
    @Test func theBundledCorpusHoldsTheWholeBook() async throws {
        let categories = try await repository.categories()

        #expect(categories.count == 132)
        #expect(Set(categories.map(\.id)).count == 132, "slugs must be unique")
        #expect(Set(categories.map(\.sortOrder)) == Set(1...132), "chapter numbers must be 1...132")
    }

    /// Grouped in the corpus's order, and the book's order inside each group. The list screen
    /// only cuts where the group changes, so an unordered fetch would show as a shuffled list.
    @Test func chaptersArriveGroupedAndInTheBooksOrderWithinAGroup() async throws {
        let categories = try await repository.categories()

        var seen: [AdhkarGroup] = []
        for category in categories where seen.last != category.group {
            #expect(!seen.contains(category.group), "group \(category.group) is not contiguous")
            seen.append(category.group)
        }

        for group in AdhkarGroup.allCases {
            let inGroup = categories.filter { $0.group == group }
            #expect(inGroup == inGroup.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    /// Every group this build has a case for has chapters behind it. A group with none would be
    /// a heading the browse screen never draws and a case nobody can reach — which means either
    /// the enum or the metadata file has drifted.
    @Test func everyGroupHasChaptersInIt() async throws {
        let categories = try await repository.categories()

        for group in AdhkarGroup.allCases {
            #expect(categories.contains { $0.group == group }, "no chapter is in \(group)")
        }
    }

    /// Home's shortcut circle and the `noor://adhkar?period=…` deep link both name this slug in
    /// code. If the corpus stops carrying it, both open a screen that says the chapter could not
    /// be loaded — which is exactly the failure this test is here to turn into a red build.
    @Test func theChapterHomeAndTheDeepLinkNameIsInTheCorpus() async throws {
        let category = try #require(
            await repository.category(id: AdhkarCategory.morningAndEveningID)
        )

        #expect(category.dhikrCount > 1)
    }

    @Test func anUnknownSlugIsNilRatherThanAnError() async throws {
        #expect(try await repository.category(id: "no-such-chapter") == nil)
    }

    // MARK: Contents

    /// Every chapter has adhkar in it, every dhikr has words and a workable count, and the
    /// count on the row matches what the reading screen will be handed.
    @Test func everyChapterHasAdhkarAndACountThatMatchesIt() async throws {
        for category in try await repository.categories() {
            let adhkar = try await repository.adhkar(in: category)

            #expect(!adhkar.isEmpty, "\(category.id) is a row leading to an empty screen")
            #expect(
                adhkar.count == category.dhikrCount,
                "\(category.id) counts \(category.dhikrCount) but returns \(adhkar.count)"
            )
            #expect(Set(adhkar.map(\.id)).count == adhkar.count, "ids must be unique in a chapter")

            for dhikr in adhkar {
                #expect(!dhikr.arabicText.isEmpty, "dhikr \(dhikr.id) has no text")
                // Clamped in the mapper as well as checked by the schema: a counter that can
                // never be completed would be worse than a wrong number.
                #expect(dhikr.repeatCount >= 1, "dhikr \(dhikr.id) is said \(dhikr.repeatCount) times")
            }
        }
    }

    /// The whole corpus is Arabic — no translation, no transliteration, no citation — and a
    /// Latin letter in a dhikr means a column from somewhere else has been read into it.
    ///
    /// The same test `HadithRepositoryTests` makes, for the same reason: it is the cheapest way to
    /// notice that a rebuild started pulling a translated edition.
    @Test func theTextIsArabicThroughout() async throws {
        let latin = CharacterSet(charactersIn: "a"..."z").union(CharacterSet(charactersIn: "A"..."Z"))

        for category in try await repository.categories() {
            for dhikr in try await repository.adhkar(in: category) {
                #expect(
                    dhikr.arabicText.rangeOfCharacter(from: latin) == nil,
                    "dhikr \(dhikr.id) carries a Latin letter"
                )
            }
        }
    }

    /// Every chapter title exists in both languages, because the browse row shows both and an
    /// empty one is a row with a blank line under it.
    @Test func everyChapterIsTitledInBothLanguages() async throws {
        for category in try await repository.categories() {
            #expect(!category.titleArabic.isEmpty, "\(category.id) has no Arabic title")
            #expect(!category.titleEnglish.isEmpty, "\(category.id) has no English title")
            #expect(category.title(in: .arabic) == category.titleArabic)
            #expect(category.title(in: .english) == category.titleEnglish)
        }
    }

    /// The build folds the source's Arabic presentation forms away with NFKC. Three chapter
    /// titles arrive written in them — `اﻟﻤﺠلس` is glyph codepoints rather than letters — and a
    /// title in that form looks correct on screen while matching nothing a reader types.
    @Test func noTitleCarriesArabicPresentationForms() async throws {
        let presentationForms = CharacterSet(
            charactersIn: UnicodeScalar(0xFB50)!...UnicodeScalar(0xFDFF)!
        ).union(CharacterSet(charactersIn: UnicodeScalar(0xFE70)!...UnicodeScalar(0xFEFF)!))
            // The ornate parentheses that mark Quranic quotation are in this block and have no
            // NFKC mapping. They are typography, not damage, and they stay.
            .subtracting(CharacterSet(charactersIn: "﴾﴿"))

        for category in try await repository.categories() {
            #expect(
                category.titleArabic.rangeOfCharacter(from: presentationForms) == nil,
                "\(category.id) is titled in presentation forms"
            )
        }
    }

    // MARK: Failure

    /// A corpus that is not in the bundle must surface as an error the screen can explain, not
    /// as a trap on launch.
    @Test func aMissingCorpusThrowsRatherThanCrashing() async {
        let repository = AdhkarRepository(database: CorpusDatabase(name: "not-a-real-corpus"))

        await #expect(throws: CorpusDatabaseError.resourceMissing(name: "not-a-real-corpus.sqlite")) {
            try await repository.categories()
        }
    }
}
