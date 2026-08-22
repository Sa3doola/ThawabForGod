//
//  ArabicSearchQuery.swift
//  ThawabForGod
//

import Foundation

/// What a reader typed, folded into the form the corpora are indexed in.
///
/// **The folding here must stay identical to the one in the build scripts** —
/// `Tools/CorpusBuilder/build_quran_db.py` and `build_hadith_db.py`, whose `normalize` is the
/// other half of the same rule. A corpus is folded once at build time, a query is folded once per
/// search, and a match is only possible where the two agree. A change to either without the other
/// silently stops finding things, which is why the rule is stated once per side and tested against
/// the shipped corpora rather than against a fixture.
///
/// It is in `Core` rather than in a feature because there are now two of those corpora and the
/// rule is the same for both. It was the Quran's alone at first, and the argument for moving it is
/// the one the Quran's own documentation makes: two copies of a folding rule are two things to
/// keep in step, and the failure when they drift is silence rather than an error.
///
/// **It is not a folding of any particular script's orthography.** The mushaf spells ٱلسَّمَٰوَٰتِ,
/// whose letters alone are `السموت` — a word no reader will ever type — so `quran.sqlite` indexes
/// Tanzil's Simple Clean text instead, in the modern spelling readers actually use. The hadith
/// need no such second text, being printed in ordinary vowelled Arabic. Either way, what arrives
/// here is what a reader types, and this folds it the same way.
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
        tokens = Self.fold(raw)
    }

    /// Whether there is anything to search for. True for whitespace, and for punctuation alone.
    var isEmpty: Bool { tokens.isEmpty }

    // MARK: The folding

    /// The letters that survive but are written more than one way. Mirrors `LETTER_FOLDING`.
    private static let letterFolding: [Unicode.Scalar: Unicode.Scalar] = [
        "أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا",   // every hamza-bearing alef
        "ة": "ه",                                  // ta marbuta, which readers type as ha
        "ى": "ي",                                  // alef maqsura
        "ؤ": "و",
        "ئ": "ي",
    ]

    /// The tatweel — a typographic stretch, not a letter, though Unicode files it as one.
    ///
    /// Dropped rather than treated as a separator, which is the difference between `الرحـــمن`
    /// folding to `الرحمن` and folding to two words that match nothing. Its own constant because
    /// it is the one character that is neither folded nor a boundary.
    private static let tatweel: Unicode.Scalar = "ـ"

    /// Every combining mark dropped, the ambiguous letters folded together, the rest split into
    /// words. Mirrors `normalize()` in the build scripts — see the note on this type.
    private static func fold(_ raw: String) -> [String] {
        var tokens: [String] = []
        var token = ""

        for scalar in raw.unicodeScalars {
            // Every Arabic diacritic. The same test the build scripts make with
            // `unicodedata.combining`, which is this property under another name.
            guard scalar.properties.canonicalCombiningClass.rawValue == 0 else { continue }
            guard scalar != tatweel else { continue }

            let folded = letterFolding[scalar] ?? scalar

            if CharacterSet.alphanumerics.contains(folded) {
                token.unicodeScalars.append(folded)
            } else if !token.isEmpty {
                // Anything else ends the word — whitespace, punctuation, the tatweel, and every
                // character FTS5 would otherwise have read as an operator.
                tokens.append(token)
                token = ""
            }
        }

        if !token.isEmpty { tokens.append(token) }
        return tokens
    }
}
