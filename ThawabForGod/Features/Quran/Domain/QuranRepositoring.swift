//
//  QuranRepositoring.swift
//  ThawabForGod
//

import Foundation

/// Reads the Quran. The feature depends on this, never on GRDB or SQL.
///
/// Every method is a read: the corpus is unchanging, and where a reader has got to is the
/// business of a different store entirely — see `Core/Persistence` for the one that holds what
/// the user changes. `async` because the implementation goes to a file, and a screen must not
/// block a frame waiting on it.
///
/// - Note: no `language` parameter, unlike `AdhkarRepositoring`. The verse text is Arabic for
///   every reader, and the chapter names carry all three spellings on the entity — so there is
///   nothing here for a language to select, and translations arrive as their own protocol
///   rather than as an argument threaded through this one.
nonisolated protocol QuranRepositoring: Sendable {

    /// All 114 chapters, in the order of the mushaf.
    func surahs() async throws -> [Surah]

    /// One chapter, or `nil` if the corpus has no such number.
    func surah(_ number: Int) async throws -> Surah?

    /// Every verse of a chapter, in order. Empty for a chapter the corpus does not have.
    func verses(inSurah surahNumber: Int) async throws -> [Verse]

    /// The thirty parts, in order, each as the range it covers.
    func juzList() async throws -> [Juz]

    /// Every verse of a part, in order — across chapter boundaries, which is the whole point
    /// of reading by juz.
    func verses(inJuz juz: Int) async throws -> [Verse]

    /// The chapters and verses a query matches, most relevant first.
    ///
    /// Takes an `ArabicSearchQuery` rather than a `String` so that the folding — which has to
    /// agree with how the corpus was built, character for character — happens in one place that
    /// both the caller and the test suite can see, rather than inside whichever implementation
    /// happens to be behind this protocol.
    ///
    /// - Parameter limit: how many verses to return at most. The count of *all* matches comes
    ///   back regardless, so a capped list can say what it is a cap on.
    func search(_ query: ArabicSearchQuery, limit: Int) async throws -> QuranSearchResults
}
