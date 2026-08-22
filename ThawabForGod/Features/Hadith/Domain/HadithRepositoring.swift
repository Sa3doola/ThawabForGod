//
//  HadithRepositoring.swift
//  ThawabForGod
//

import Foundation

/// Reads the hadith corpus. The feature depends on this, never on GRDB or SQL.
///
/// Every method is a read, for the reason `QuranRepositoring`'s are: the corpus is unchanging,
/// and anything the reader marks belongs to `Core/Persistence`'s store instead. `async` because
/// the implementation goes to a file, and a screen must not block a frame waiting on it.
///
/// - Note: no `language` parameter. The narrations are Arabic for every reader and the titles
///   carry both spellings on the entity, so there is nothing here for a language to select.
nonisolated protocol HadithRepositoring: Sendable {

    /// The collections the corpus carries, in the order they are conventionally listed.
    func collections() async throws -> [HadithCollection]

    /// The kitab a collection is divided into, in order. Empty for a collection it does not have.
    func books(inCollection collectionID: String) async throws -> [HadithBook]

    /// One kitab, or `nil` if the corpus has no such division.
    ///
    /// Its own method rather than a filter over `books(inCollection:)` because the reading screen
    /// is reachable without the list above it having been drawn — a restored tab, and later a
    /// bookmark or a deep link — and loading 97 divisions to name one is work for nothing.
    func book(_ reference: BookReference) async throws -> HadithBook?

    /// Every narration in a kitab, in reference order.
    func hadiths(inBook reference: BookReference) async throws -> [Hadith]

    /// The narrations with these identities, in whatever order the corpus returns them.
    ///
    /// What a bookmark list is made of. Bookmarks store a reference and nothing else — the words
    /// belong to the corpus, not to the reader — so the list is a join done here rather than a
    /// copy of the text kept in the other store. Unordered on purpose: the caller knows the order
    /// it wants, which for bookmarks is by when they were kept and not by anything the corpus has
    /// an opinion about.
    ///
    /// Identities the corpus does not have are simply absent from the result, which is how a
    /// bookmark left over from a corpus that has since been rebuilt fails: one row missing from a
    /// list, rather than an error on a screen.
    func hadiths(_ ids: [HadithID]) async throws -> [Hadith]

    /// The narrations a query matches, most relevant first.
    ///
    /// Takes an `ArabicSearchQuery` rather than a `String` so that the folding — which has to
    /// agree with how the corpus was built, character for character — happens in one place that
    /// both the caller and the test suite can see, rather than inside whichever implementation
    /// happens to be behind this protocol.
    ///
    /// Across both collections, deliberately. A reader who remembers a phrase does not usually
    /// remember which of the two Sahihs it is in, and asking them to choose before searching
    /// would be asking the question the search is meant to answer.
    ///
    /// - Parameter limit: how many narrations to return at most. The count of *all* matches comes
    ///   back regardless, so a capped list can say what it is a cap on.
    func search(_ query: ArabicSearchQuery, limit: Int) async throws -> HadithSearchResults
}
