//
//  QuranSearchQueryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The folding a query goes through before it meets the index.
///
/// This suite is one half of a rule whose other half is in Python: `QuranSearchQuery` must fold a
/// typed word into exactly what `build_quran_db.py` wrote into `verse.text_normalized`. The cases
/// below are the rule stated in Swift; `QuranRepositoryTests.search` is the same rule checked
/// against the corpus that actually shipped, which is what catches the two drifting apart.
struct QuranSearchQueryTests {

    // MARK: The marks come off

    @Test func diacriticsAreDropped() {
        #expect(QuranSearchQuery("ٱلرَّحْمَٰنِ").tokens == ["الرحمن"])
    }

    @Test func aVowelledWordFoldsToTheSameThingAsItsBareForm() {
        #expect(QuranSearchQuery("مُحَمَّد").tokens == QuranSearchQuery("محمد").tokens)
    }

    // MARK: One spelling per letter

    @Test(arguments: [
        ("أحد", "احد"),
        ("إبراهيم", "ابراهيم"),
        ("آمنوا", "امنوا"),
        ("ٱلله", "الله"),
    ])
    func everyHamzaBearingAlefFoldsToAPlainOne(typed: String, folded: String) {
        #expect(QuranSearchQuery(typed).tokens == [folded])
    }

    @Test func taMarbutaFoldsToHa() {
        #expect(QuranSearchQuery("القيامة").tokens == ["القيامه"])
    }

    @Test func alefMaqsuraFoldsToYa() {
        #expect(QuranSearchQuery("موسى").tokens == ["موسي"])
    }

    @Test func tatweelIsRemovedRatherThanSplittingTheWord() {
        #expect(QuranSearchQuery("الرحـــمن").tokens == ["الرحمن"])
    }

    // MARK: Words

    @Test func wordsAreSeparateTokensInTheOrderTheyWereTyped() {
        #expect(QuranSearchQuery("الحمد لله رب").tokens == ["الحمد", "لله", "رب"])
    }

    @Test func repeatedAndSurroundingWhitespaceIsIgnored() {
        #expect(QuranSearchQuery("  الحمد   لله \n").tokens == ["الحمد", "لله"])
    }

    @Test func aTransliterationSplitsOnItsHyphenTheWayTheIndexDoes() {
        #expect(QuranSearchQuery("Al-Baqara").tokens == ["Al", "Baqara"])
    }

    // MARK: Nothing typed can be read as FTS5 syntax

    /// The reason tokens are letters and digits and nothing else. A quote reaching the query
    /// expression unescaped would be a syntax error rather than a search, and `*` or `NEAR(` would
    /// be an operator the reader did not ask for.
    @Test(arguments: ["\"", "*", "()", "^", ":", "-", "\"الحمد\""])
    func punctuationNeverSurvivesIntoAToken(typed: String) {
        let tokens = QuranSearchQuery(typed).tokens
        #expect(tokens.allSatisfy { $0.allSatisfy(\.isLetter) || $0.allSatisfy(\.isNumber) })
        #expect(!tokens.contains { $0.contains("\"") || $0.contains("*") })
    }

    @Test func quotesAroundAWordLeaveTheWord() {
        #expect(QuranSearchQuery("\"الحمد\"").tokens == ["الحمد"])
    }

    // MARK: Empty

    @Test(arguments: ["", "   ", "\n", "،", "!؟.", "***"])
    func aQueryWithNoLettersOrDigitsIsEmpty(typed: String) {
        #expect(QuranSearchQuery(typed).isEmpty)
    }

    @Test func aQueryWithAWordIsNotEmpty() {
        #expect(!QuranSearchQuery("الله").isEmpty)
    }
}
