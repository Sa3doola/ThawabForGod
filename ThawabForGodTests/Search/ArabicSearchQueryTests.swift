//
//  ArabicSearchQueryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The folding a query goes through before it meets the index.
///
/// This suite is one half of a rule whose other half is in Python: `ArabicSearchQuery` must fold a
/// typed word into exactly what `build_quran_db.py` and `build_hadith_db.py` fed their indexes.
/// The cases below are the rule stated in Swift; the search tests in `QuranRepositoryTests` and
/// `HadithRepositoryTests` are the same rule checked against the corpora that actually shipped,
/// which is what catches the two sides drifting apart.
struct ArabicSearchQueryTests {

    // MARK: The marks come off

    @Test func diacriticsAreDropped() {
        #expect(ArabicSearchQuery("ٱلرَّحْمَٰنِ").tokens == ["الرحمن"])
    }

    @Test func aVowelledWordFoldsToTheSameThingAsItsBareForm() {
        #expect(ArabicSearchQuery("مُحَمَّد").tokens == ArabicSearchQuery("محمد").tokens)
    }

    // MARK: One spelling per letter

    @Test(arguments: [
        ("أحد", "احد"),
        ("إبراهيم", "ابراهيم"),
        ("آمنوا", "امنوا"),
        ("ٱلله", "الله"),
    ])
    func everyHamzaBearingAlefFoldsToAPlainOne(typed: String, folded: String) {
        #expect(ArabicSearchQuery(typed).tokens == [folded])
    }

    @Test func taMarbutaFoldsToHa() {
        #expect(ArabicSearchQuery("القيامة").tokens == ["القيامه"])
    }

    @Test func alefMaqsuraFoldsToYa() {
        #expect(ArabicSearchQuery("موسى").tokens == ["موسي"])
    }

    @Test func tatweelIsRemovedRatherThanSplittingTheWord() {
        #expect(ArabicSearchQuery("الرحـــمن").tokens == ["الرحمن"])
    }

    // MARK: Words

    @Test func wordsAreSeparateTokensInTheOrderTheyWereTyped() {
        #expect(ArabicSearchQuery("الحمد لله رب").tokens == ["الحمد", "لله", "رب"])
    }

    @Test func repeatedAndSurroundingWhitespaceIsIgnored() {
        #expect(ArabicSearchQuery("  الحمد   لله \n").tokens == ["الحمد", "لله"])
    }

    @Test func aTransliterationSplitsOnItsHyphenTheWayTheIndexDoes() {
        #expect(ArabicSearchQuery("Al-Baqara").tokens == ["Al", "Baqara"])
    }

    // MARK: Nothing typed can be read as FTS5 syntax

    /// The reason tokens are letters and digits and nothing else. A quote reaching the query
    /// expression unescaped would be a syntax error rather than a search, and `*` or `NEAR(` would
    /// be an operator the reader did not ask for.
    @Test(arguments: ["\"", "*", "()", "^", ":", "-", "\"الحمد\""])
    func punctuationNeverSurvivesIntoAToken(typed: String) {
        let tokens = ArabicSearchQuery(typed).tokens
        #expect(tokens.allSatisfy { $0.allSatisfy(\.isLetter) || $0.allSatisfy(\.isNumber) })
        #expect(!tokens.contains { $0.contains("\"") || $0.contains("*") })
    }

    @Test func quotesAroundAWordLeaveTheWord() {
        #expect(ArabicSearchQuery("\"الحمد\"").tokens == ["الحمد"])
    }

    // MARK: Empty

    @Test(arguments: ["", "   ", "\n", "،", "!؟.", "***"])
    func aQueryWithNoLettersOrDigitsIsEmpty(typed: String) {
        #expect(ArabicSearchQuery(typed).isEmpty)
    }

    @Test func aQueryWithAWordIsNotEmpty() {
        #expect(!ArabicSearchQuery("الله").isEmpty)
    }
}
