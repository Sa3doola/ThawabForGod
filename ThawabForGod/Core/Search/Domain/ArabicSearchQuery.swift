//
//  ArabicSearchQuery.swift
//  ThawabForGod
//

import ArabicText
import Foundation

/// What a reader typed, folded into the form the corpora are indexed in.
///
/// **The folding is `ArabicNormalizer`'s, in `Packages/ArabicText`**, and this type only gives it a
/// shape the repositories can ask for. The rule is stated once there because three things fold with
/// it and a match is only possible where they agree: `Tools/QuranBuilder` folds the Quran's index,
/// this folds every query, and the hadith index — still built by
/// `Tools/CorpusBuilder/build_hadith_db.py` — folds with a Python `normalize()` that the package's
/// `HadithParityTests` holds to the Swift one. A change on one side without the others does not
/// fail; it silently stops finding things.
///
/// It is in `Core` rather than in a feature because two corpora ask the same question of it — the
/// argument the Quran's own documentation makes: two copies of a folding rule are two things to
/// keep in step, and the failure when they drift is silence rather than an error.
///
/// **It is not a folding of any particular script's orthography.** The mushaf spells ٱلسَّمَٰوَٰتِ,
/// whose letters alone are `السموت` — a word no reader will ever type — so the Quran's index is
/// built over Tanzil's Simple Clean text instead, in the modern spelling readers actually use. The
/// hadith need no such second text, being printed in ordinary vowelled Arabic. Either way, what
/// arrives here is what a reader types, and this folds it the same way.
nonisolated struct ArabicSearchQuery: Hashable, Sendable {

    /// The query as a list of folded words, in the order they were typed.
    ///
    /// Split on anything that is not a letter or a digit, which is also how FTS5's `unicode61`
    /// tokenizer splits the indexed text — so `Al-Baqara` is two tokens on both sides. It has a
    /// second effect worth naming: a token can only ever be letters and digits, so nothing a
    /// reader types can be read as FTS5 syntax. A stray quote or `*` becomes a separator rather
    /// than an operator.
    let tokens: [String]

    init(_ raw: String) {
        tokens = ArabicNormalizer.words(in: raw)
    }

    /// Whether there is anything to search for. True for whitespace, and for punctuation alone.
    var isEmpty: Bool { tokens.isEmpty }
}
