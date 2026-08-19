//
//  Surah.swift
//  ThawabForGod
//

import Foundation

/// One of the 114 chapters, as the list screen needs it.
///
/// Three names rather than one, because the reader's language decides which two of them are
/// worth showing and the Arabic is always worth showing. A value type with no tie to the
/// database row it came from, so it crosses back off the reader queue without a thought.
nonisolated struct Surah: Identifiable, Hashable, Sendable {

    /// Its place in the mushaf, 1...114 — which is also its identity. Stable forever: the order
    /// of the chapters is not a detail of this corpus.
    let id: Int

    /// The chapter's name in Arabic, vowelled as the corpus stores it — `الفاتحة`.
    let arabicName: String

    /// The same name in Latin letters, for a reader who does not read the script — `Al-Faatiha`.
    let transliteration: String

    /// What the name means — `The Opening`. English only; the corpus has no other translation
    /// of it, and an Arabic reader has the name itself.
    let englishName: String

    /// How many verses it has. Worth carrying on the entity rather than counting rows: the list
    /// screen shows it without loading a single verse.
    let verseCount: Int

    /// Where it was revealed.
    let revelationPlace: RevelationPlace

    /// Its place in the order of revelation, which is not its place in the mushaf.
    let revelationOrder: Int

    /// The basmala printed above the chapter, unnumbered.
    ///
    /// `nil` for exactly two: Al-Fatiha, whose basmala *is* verse 1 and is therefore in the
    /// verses, and At-Tawba, which has none at all. Everywhere else the corpus lifted it off
    /// verse 1 so the reading screen can draw it as a heading — see the corpus build script.
    let bismillah: String?
}

/// Where a chapter was revealed — the two the mushaf distinguishes.
nonisolated enum RevelationPlace: String, Hashable, Sendable, CaseIterable {
    case meccan
    case medinan
}
