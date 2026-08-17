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
/// and a screen that says the adhkar could not be loaded. It also exercises `DhikrRecord`'s
/// `init(row:)`, which nothing else can reach without linking GRDB into the test target.
struct AdhkarRepositoryTests {

    private let repository = AdhkarRepository(database: CorpusDatabase(name: "corpus"))

    // MARK: Categories

    @Test func theBundledCorpusHoldsBothCategoriesInReadingOrder() async throws {
        #expect(try await repository.categories() == [.morning, .evening])
    }

    // MARK: Contents

    @Test(arguments: AdhkarCategory.allCases)
    func everyCategoryHasAdhkarWithEveryFieldPopulated(category: AdhkarCategory) async throws {
        let adhkar = try await repository.adhkar(in: category, language: .english)

        #expect(!adhkar.isEmpty)

        for dhikr in adhkar {
            #expect(!dhikr.arabicText.isEmpty, "dhikr \(dhikr.id) has no text")
            #expect(!dhikr.reference.isEmpty, "dhikr \(dhikr.id) has no source")
            // Clamped in the mapper, so a zero in the data cannot reach here — a counter that
            // can never be completed would be worse than a wrong number.
            #expect(dhikr.repeatCount >= 1, "dhikr \(dhikr.id) asks to be said \(dhikr.repeatCount) times")
        }

        #expect(Set(adhkar.map(\.id)).count == adhkar.count, "ids must be unique within a category")
    }

    /// The upstream data marks 16 of the 34 adhkar as belonging to both times of day. If the
    /// build step ever collapsed that back into one category per dhikr, the evening list would
    /// silently lose two thirds of itself.
    @Test func theTwoCategoriesOverlapWithoutBeingIdentical() async throws {
        let morning = try await repository.adhkar(in: .morning, language: .english)
        let evening = try await repository.adhkar(in: .evening, language: .english)

        let morningIDs = Set(morning.map(\.id))
        let eveningIDs = Set(evening.map(\.id))

        #expect(!morningIDs.intersection(eveningIDs).isEmpty, "no dhikr is read at both times")
        #expect(morningIDs != eveningIDs, "the two categories are the same list")
    }

    // MARK: Language

    @Test func anEnglishReaderGetsTheTranslationAndTheEnglishCitation() async throws {
        let dhikr = try #require(
            await repository.adhkar(in: .morning, language: .english).first
        )

        #expect(dhikr.translation?.isEmpty == false)
        #expect(dhikr.transliteration?.isEmpty == false)
        // Both citations are prose, but only one of them is in Arabic script.
        #expect(!dhikr.reference.contains("برقم"))
    }

    /// For an Arabic reader the text *is* the dhikr: there is nothing to translate it into, and
    /// the reading view uses these `nil`s to decide there is no toggle worth offering.
    @Test func anArabicReaderGetsNoTranslationAndTheArabicCitation() async throws {
        let arabic = try #require(await repository.adhkar(in: .morning, language: .arabic).first)
        let english = try #require(await repository.adhkar(in: .morning, language: .english).first)

        #expect(arabic.translation == nil)
        #expect(arabic.transliteration == nil)
        #expect(arabic.id == english.id)
        #expect(arabic.arabicText == english.arabicText, "the Arabic text does not depend on language")
        #expect(arabic.reference != english.reference)
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
