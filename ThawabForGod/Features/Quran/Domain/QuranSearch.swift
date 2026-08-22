//
//  QuranSearch.swift
//  ThawabForGod
//

import Foundation

/// What a search found: the chapters whose name matched, and the verses whose text did.
///
/// Both in one value rather than two calls, because they are one question — a reader typing
/// `الفاتحة` may want the chapter or may want the verse that names it, and which of the two they
/// meant is not something the app can know before showing them.
nonisolated struct QuranSearchResults: Equatable, Sendable {

    /// The chapters whose Arabic name, transliteration or English name matched.
    let surahs: [Surah]

    /// The matching verses, most relevant first, capped at the limit the search was given.
    let verses: [Verse]

    /// How many verses matched in total, which is not `verses.count` once the cap bites.
    ///
    /// Carried so the screen can say how many there are rather than quietly showing the first
    /// hundred of two hundred as though that were all of them.
    let totalVerseMatches: Int

    static let none = QuranSearchResults(surahs: [], verses: [], totalVerseMatches: 0)

    var isEmpty: Bool { surahs.isEmpty && verses.isEmpty }
}
