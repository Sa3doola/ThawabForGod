//
//  Juz.swift
//  ThawabForGod
//

import Foundation

/// One of the thirty parts, as a range to jump to.
///
/// Stored as a closed range rather than a start alone, so "read juz 7" is one query with two
/// bounds rather than a lookup of where juz 8 begins. The end is rarely the verse before the
/// next start by number: a part that opens on a new chapter ends on the last verse of the one
/// before it.
nonisolated struct Juz: Identifiable, Hashable, Sendable {

    /// 1...30, which is also its identity and its name.
    let id: Int

    /// The first verse of the part.
    let start: VerseReference

    /// The last verse of the part, inclusive.
    let end: VerseReference

    var number: Int { id }
}
