//
//  FTS5Query.swift
//  ThawabForGod
//

import Foundation

/// A folded query as the two FTS5 match expressions it can be read as, and the order to try them.
///
/// **Infrastructure, not Domain**: what it builds is SQLite FTS5 syntax, so it belongs beside the
/// repositories that speak SQL and nowhere above them. It names no GRDB type, which is what lets
/// it be tested without a database.
///
/// It exists because the Quran and the hadith ask the same question of two different indexes.
/// Both want "the fragment the reader is quoting, and only failing that the words they named",
/// and the reasoning behind that order is identical in both — so it is written once here rather
/// than twice in two repositories.
nonisolated struct FTS5Query: Sendable, Equatable {

    /// The tokens as one phrase, the last word open-ended — `"الحمد لل" *`.
    ///
    /// A phrase rather than a set of words because of what a reader is usually doing: typing a
    /// fragment they half-remember, in order. `الحمد لله` should find the passage that says it,
    /// not every passage that happens to contain both words somewhere.
    ///
    /// The trailing `*` is what makes results arrive while the query is still being typed —
    /// without it, `الرح` matches nothing until the word is finished.
    let phrase: String

    /// The same tokens as separate words, all of which must appear — `"موسي" "فرعون" *`.
    ///
    /// The fallback, for the reader who is not quoting a text but naming two things in it. FTS5
    /// puts an implicit AND between phrases, so this is "contains both", anywhere in the row.
    let keywords: String

    /// - Precondition: `query` is not empty. A query with no tokens has no expression to build —
    ///   `""` is not valid FTS5 syntax, and `"" *` matches everything. Callers check `isEmpty`
    ///   and return early rather than searching for nothing.
    init(_ query: ArabicSearchQuery) {
        precondition(!query.isEmpty, "an empty query has no FTS5 expression")

        phrase = "\"\(query.tokens.joined(separator: " "))\" *"

        let quoted = query.tokens.map { "\"\($0)\"" }
        let last = quoted[quoted.count - 1]
        keywords = (quoted.dropLast() + ["\(last) *"]).joined(separator: " ")
    }

    /// Runs the phrase reading, and falls back to the keyword one only if it found nothing.
    ///
    /// In that order, and not merged: a row containing the typed fragment is a better answer than
    /// one merely containing its words, and ranking them together would let the second kind
    /// outscore the first. Falling back only on an empty result means the loose reading costs
    /// nothing when the strict one worked, which is most of the time.
    func matched<T>(_ fetch: (String) throws -> [T]) rethrows -> [T] {
        let matches = try fetch(phrase)
        return matches.isEmpty ? try fetch(keywords) : matches
    }

    /// The same fallback, but reporting *which* expression won.
    ///
    /// The count and the rows have to come from the same reading of the query, or the screen says
    /// "180 results" above a list drawn from a different search entirely.
    func matching(_ count: (String) throws -> Int) rethrows -> (expression: String, total: Int) {
        let total = try count(phrase)
        if total > 0 { return (phrase, total) }
        return (keywords, try count(keywords))
    }
}
