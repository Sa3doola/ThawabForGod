//
//  HadithSearch.swift
//  ThawabForGod
//

import Foundation

/// What a search of the hadith found.
///
/// Narrations only, unlike `QuranSearchResults` — there is no second kind of answer to offer. The
/// Quran's search matches chapter *names* as well as verses because a reader typing `الفاتحة`
/// plausibly wants the chapter; the equivalent here would be the kitab titles, and `كتاب الإيمان`
/// is the title of a division in both collections, so matching it would offer two rows that say
/// the same words and lead to different places. A reader looking for a kitab has a list of 97 to
/// scroll; a reader typing into this field is looking for a narration.
nonisolated struct HadithSearchResults: Equatable, Sendable {

    /// The matching narrations, most relevant first, capped at the limit the search was given.
    let hadiths: [Hadith]

    /// How many matched in total, which is not `hadiths.count` once the cap bites.
    ///
    /// Carried so the screen can say how many there are rather than quietly showing the first
    /// hundred of nine hundred as though that were all of them. It matters more here than in the
    /// Quran: a common word in fifteen thousand narrations of isnad and matn matches a great many
    /// more rows than the same word in six thousand verses.
    let total: Int

    static let none = HadithSearchResults(hadiths: [], total: 0)

    var isEmpty: Bool { hadiths.isEmpty }
}
