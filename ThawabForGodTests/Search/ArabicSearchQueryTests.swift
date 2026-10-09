//
//  ArabicSearchQueryTests.swift
//  ThawabForGodTests
//

import Foundation
import SQLite3
import Testing
@testable import ThawabForGod

/// The folding a query goes through before it meets the index.
///
/// This suite is one half of a rule whose other half is at build time: `ArabicSearchQuery` must fold
/// a typed word into exactly what the indexes were fed. The fold itself is `ArabicNormalizer`'s
/// (`Packages/ArabicText`, with its own suite and the Python parity probes); the cases below are the
/// rule as a query sees it, and the search tests in `QuranRepositoryTests` and
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

    /// Uthmani spelling's small waw and small yeh, pasted from a mushaf, fold away like the tatweel.
    @Test func smallWawAndSmallYehAreRemovedRatherThanSplittingTheWord() {
        #expect(ArabicSearchQuery("بِهِۦ لَهُۥ").tokens == ["به", "له"])
    }

    /// ۞ and ۩ sit between words, so they end one — a pasted `قل۞هو` is still two words.
    @Test func theQuranicSignsEndAWord() {
        #expect(ArabicSearchQuery("قل۞هو").tokens == ["قل", "هو"])
        #expect(ArabicSearchQuery("يسجدون۩").tokens == ["يسجدون"])
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

    // MARK: The hadith index

    /// The one place the query's fold and the hadith index's differ: Python keeps the small waw and
    /// small yeh as letters, and the query drops them. That can only matter if the index holds a
    /// word with one of them in it — which it cannot, because the text it was built from has none.
    /// Checked against the database that shipped, so a hadith rebuild that changed this fails here.
    @Test func theHadithTextHoldsNeitherLetterTheTwoFoldsDisagreeOn() throws {
        let url = try #require(Bundle.main.url(forResource: "hadith", withExtension: "sqlite"))

        var database: OpaquePointer?
        defer { sqlite3_close(database) }
        try #require(sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)

        // U+06E5 and U+06E6, spelled as code points so the query cannot be mis-encoded.
        let sql = "SELECT count(*) FROM hadith WHERE instr(text, char(1765)) OR instr(text, char(1766))"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        try #require(sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK)
        try #require(sqlite3_step(statement) == SQLITE_ROW)

        #expect(sqlite3_column_int(statement, 0) == 0)
    }
}
