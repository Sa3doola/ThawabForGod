//
//  Verse.swift
//  ThawabForGod
//

import Foundation

/// One verse, with everything the reading screen needs to place it.
///
/// The divisions travel *with* the verse rather than being looked up beside it, because the
/// reader crosses them mid-scroll: the header that says which juz is being read changes on a
/// verse boundary, and asking a second table on every scroll event to find that out would be a
/// query per frame.
nonisolated struct Verse: Identifiable, Hashable, Sendable {

    /// Chapter and number together — `2:255` — which is what makes a verse addressable by a
    /// bookmark, a search result or a deep link.
    let id: VerseReference

    /// The verse itself, in the Uthmani script, vowelled exactly as the corpus stores it.
    ///
    /// Always Arabic, whatever the app's language is. For the 112 chapters whose basmala was
    /// lifted into `Surah.bismillah`, verse 1 is what remains after it.
    let text: String

    /// Which of the thirty parts it falls in.
    let juz: Int

    /// Which of the sixty halves of those parts, 1...60.
    let hizb: Int

    /// Which quarter of a hizb, 1...240 — the finest division a reciter navigates by.
    let rubElHizb: Int

    /// The page of the Madina mushaf it falls on, 1...604. Carried for a later paged reading
    /// mode; the continuous reader ignores it.
    let page: Int

    /// The prostration this verse calls for, if it is one of the fifteen that do.
    let sajda: Sajda?

    var surahNumber: Int { id.surah }
    var number: Int { id.verse }
}

/// The two kinds of prostration the mushaf marks, which the corpus keeps apart.
///
/// Which verses are obligatory is a point the schools differ on, and flattening the distinction
/// to a single "there is a sajda here" is the app taking a position it has no business taking.
nonisolated enum Sajda: String, Hashable, Sendable, CaseIterable {
    case obligatory
    case recommended
}
