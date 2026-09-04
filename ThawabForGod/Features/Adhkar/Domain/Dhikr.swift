//
//  Dhikr.swift
//  ThawabForGod
//

import Foundation

/// One remembrance, ready to read.
///
/// **Arabic and a number, and nothing else.** The corpus behind it is Hisn al-Muslim's own text —
/// the whole book rather than the 34 morning-and-evening adhkar this feature began with — and
/// that source carries no translation, no transliteration and no per-dhikr citation. Storing
/// those as always-`nil` columns would be the app claiming a shape its data does not have; a
/// reader is better served by a screen that shows what there is and says where it came from.
///
/// The attribution moved with them, from the dhikr to the chapter: the citation is *the book*,
/// named once on the reading screen, rather than a hadith reference per line. That is a genuine
/// loss against what the old 34 rows carried, and it is recorded as one in
/// `Resources/Corpus/README.md`. Adding translations back is a data problem — a licensed English
/// edition — not a code one, and this type is where they would land.
///
/// A value type with no reference to the database it came from, so it crosses off the reader
/// queue to the main actor without a thought.
nonisolated struct Dhikr: Identifiable, Hashable, Sendable {

    /// Stable across rebuilds. Derived by the build script from the source's chapter and item
    /// numbers rather than from insertion order, so a rebuild cannot quietly renumber a dhikr
    /// something is keyed on.
    let id: Int

    /// The remembrance itself, vowelled, exactly as the corpus stores it.
    let arabicText: String

    /// How many times it is to be said. Always at least one, enforced by the schema.
    ///
    /// Where the book's own prose states a number and the upstream file's `count` field disagreed,
    /// the prose is what ships — three of the 267 — and the build script prints every one of them.
    let repeatCount: Int
}
