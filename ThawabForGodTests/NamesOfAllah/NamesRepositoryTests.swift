//
//  NamesRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Reads the corpus that actually ships.
///
/// This suite carries more weight than the equivalent for the adhkar or the tasbih, because the
/// content is a *fixed, canonical list of ninety-nine* — "there are 99 and they are in order" is
/// checkable in a way "the adhkar are correct" is not, and the data set that was rejected while
/// building this failed exactly here: it dropped one name and shifted the rest up by a place.
struct NamesRepositoryTests {

    private let repository = NamesRepository(database: CorpusDatabase(name: "corpus"))

    // MARK: Shape

    @Test func thereAreExactlyNinetyNine() async throws {
        #expect(try await repository.allNames(in: .english).count == 99)
    }

    @Test func theyAreNumberedOneThroughNinetyNineInOrder() async throws {
        let names = try await repository.allNames(in: .english)

        #expect(names.map(\.order) == Array(1...99))
    }

    // MARK: Contents

    @Test(arguments: AppLanguage.allCases)
    func everyNameHasArabicText(language: AppLanguage) async throws {
        let names = try await repository.allNames(in: language)

        for name in names {
            #expect(!name.arabic.isEmpty, "name \(name.order) has no Arabic")
        }
    }

    @Test func everyNameHasATransliterationAndAMeaningInEnglish() async throws {
        let names = try await repository.allNames(in: .english)

        for name in names {
            #expect(name.transliteration?.isEmpty == false, "name \(name.order) has no transliteration")
            #expect(name.meaning?.isEmpty == false, "name \(name.order) has no meaning")
        }
    }

    @Test func theNamesAreDistinct() async throws {
        let names = try await repository.allNames(in: .english)

        #expect(Set(names.map(\.arabic)).count == 99, "the list repeats a name")
    }

    /// Spot checks at both ends and either side of the place where the rejected data set went
    /// wrong. If a rebuild ever shifts the list again, this is what catches it.
    @Test(arguments: [
        (1, "Ar Rahmaan"),
        (67, "Al Ahad"),
        (68, "As Samad"),
        (99, "As Saboor")
    ])
    func knownPositionsHoldTheExpectedNames(order: Int, transliteration: String) async throws {
        let names = try await repository.allNames(in: .english)
        let name = try #require(names.first { $0.order == order })

        #expect(name.transliteration == transliteration)
    }

    // MARK: What is deliberately absent

    /// Every freely-licensed set of explanations found was AI-generated, so the column ships
    /// empty rather than invented. If a verified source is ever added, this test is the reminder
    /// to delete it.
    @Test func noNameCarriesAnExplanationYet() async throws {
        let names = try await repository.allNames(in: .english)

        #expect(names.allSatisfy { $0.explanation == nil })
    }

    // MARK: Language

    @Test func anArabicReaderGetsTheNameAndNoGloss() async throws {
        let arabic = try await repository.allNames(in: .arabic)
        let english = try await repository.allNames(in: .english)

        #expect(arabic.allSatisfy { $0.transliteration == nil })
        #expect(arabic.allSatisfy { $0.meaning == nil })
        #expect(arabic.map(\.arabic) == english.map(\.arabic), "the names do not depend on language")
    }

    /// Chapter and verse numbers mean the same thing in both languages, so unlike the meaning
    /// they are not stripped for an Arabic reader — it is the one part of the detail screen they
    /// can still check the app against.
    @Test func theQuranReferenceSurvivesInBothLanguages() async throws {
        let arabic = try await repository.allNames(in: .arabic)
        let english = try await repository.allNames(in: .english)

        #expect(arabic.map(\.reference) == english.map(\.reference))
        #expect(arabic.contains { $0.reference?.isEmpty == false })
    }

    // MARK: Failure

    @Test func aMissingCorpusThrowsRatherThanCrashing() async {
        let repository = NamesRepository(database: CorpusDatabase(name: "not-a-real-corpus"))

        await #expect(throws: CorpusDatabaseError.resourceMissing(name: "not-a-real-corpus.sqlite")) {
            try await repository.allNames(in: .english)
        }
    }
}
