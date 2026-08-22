//
//  HadithBook.swift
//  ThawabForGod
//

import Foundation

/// One kitab — a division of a collection, the way a chapter divides the mushaf.
///
/// "Book" in the sense both collections use it: `كتاب الإيمان`, the Book of Faith. Not the
/// collection itself, which is `HadithCollection` — the word is overloaded in every English
/// edition of these works, and this type is the smaller of the two things it can mean.
nonisolated struct HadithBook: Identifiable, Hashable, Sendable {

    /// Which collection it divides.
    let collectionID: String

    /// Its number within that collection. Not unique across collections, and **zero is a real
    /// value** — Sahih Muslim's introduction is kitab 0.
    let number: Int

    /// Its title in Arabic — `كتاب بدء الوحى`.
    let arabicTitle: String

    /// Its title in English — `Revelation`.
    ///
    /// A description of the division rather than a translation of anything narrated, which is
    /// why it may ship where the hadith text itself may not. See the corpus README.
    let englishTitle: String

    /// How many narrations it holds.
    let hadithCount: Int

    /// The collection and number together, since neither is unique on its own.
    var id: BookReference { BookReference(collection: collectionID, number: number) }
}

/// Which kitab, of which collection — the identity of a division and the value a push carries.
///
/// Its own type rather than an interpolated string, so the two halves cannot be swapped and a
/// navigation destination can be built out of it without parsing anything back apart.
nonisolated struct BookReference: Hashable, Sendable, Identifiable {
    let collection: String
    let number: Int

    var id: Self { self }
}
