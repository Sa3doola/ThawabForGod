//
//  DivineName.swift
//  ThawabForGod
//

import Foundation

/// One of the ninety-nine names, ready to read.
///
/// Already resolved to a single language by the time it gets here, the same way `Dhikr` and
/// `TasbihDhikr` are: `arabic` is what everyone sees, and `transliteration` and `meaning` are
/// `nil` for a reader whose language is Arabic — for them the name *is* the thing, and there is
/// nothing to spell out or translate into.
nonisolated struct DivineName: Identifiable, Hashable, Sendable {

    /// The canonical position, 1 through 99. Also the identity: the third name is the third name
    /// in every language and every rebuild.
    let id: Int

    /// The name itself, vowelled. Always Arabic.
    let arabic: String

    /// How to say it, for a reader who does not read the script. `nil` when that reader's
    /// language is Arabic.
    let transliteration: String?

    /// What it means, in the reader's language. `nil` when that language is Arabic — the corpus
    /// has no Arabic glosses, and inventing one would be exactly the thing
    /// `Resources/Corpus/README.md` forbids.
    let meaning: String?

    /// A fuller explanation. **`nil` for every name today, deliberately** — every freely-licensed
    /// set of explanations found was AI-generated, and an invented gloss on a name of God is not
    /// something to ship. The field exists so a verified source can be dropped in without the
    /// screens changing.
    let explanation: String?

    /// Where the name occurs in the Quran, as chapter-and-verse citations. Facts rather than
    /// authorship, and the one part of the detail screen a reader can check for themselves.
    let reference: String?

    /// `order` reads better than `id` at the call sites that mean "the number shown on the cell",
    /// and costs nothing.
    var order: Int { id }
}
