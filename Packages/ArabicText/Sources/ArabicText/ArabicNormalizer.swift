import Foundation

/// Arabic text folded into the form every search index in the project is built over.
///
/// **One rule, three users.** `Tools/QuranBuilder` folds the Quran with it when it writes the
/// index; the app folds every typed query with it (`ArabicSearchQuery`); and the hadith index,
/// still built by `Tools/CorpusBuilder/build_hadith_db.py`, folds with a Python `normalize()` that
/// `HadithParityTests` holds to this one over a fixed probe list. A match is only possible where
/// the corpus and the query were folded the same way, so a change here without the other two
/// does not fail — it stops finding things.
///
/// For search only: the folded text is never displayed and never written back.
///
/// The steps, in order:
///
/// 1. **Canonical composition (NFC)**, as the Python side does, so a letter typed as base +
///    combining hamza folds the same as the precomposed letter.
/// 2. **Every combining mark dropped** — any scalar whose canonical combining class is not zero.
///    That is all the tashkeel, the superscript alef, and the Quranic annotation marks; the same
///    test Python makes with `unicodedata.combining`.
/// 3. **Three letter-like marks dropped**: the tatweel, a typographic stretch; and the small waw
///    and small yeh (U+06E5, U+06E6) that Uthmani spelling writes after a pronoun (بِهِۦ). Unicode
///    files all three as letters, so step 2 does not catch them, and kept they would make بهۦ a
///    different word from the به a reader types.
/// 4. **The ambiguous letters folded** to one spelling each (`letterFolding`).
/// 5. **Split into words on everything that is not a letter or a digit.** Punctuation, whitespace
///    and the three Quranic signs that are not marks — ۝ end of ayah, ۞ rub el hizb, ۩ sajdah — end
///    a word rather than vanishing inside it. In every corpus the project reads they already sit
///    beside whitespace or at a word's end, so the index is the same either way; the difference is
///    a query like `قل۞هو`, which stays two words instead of becoming one that matches nothing.
///    A word is letters and digits only, which is also what makes typed input unable to reach FTS5
///    as syntax.
public enum ArabicNormalizer {

    /// The folded words of `text`, in order.
    public static func words(in text: String) -> [String] {
        var words: [String] = []
        var word = String.UnicodeScalarView()

        for scalar in text.precomposedStringWithCanonicalMapping.unicodeScalars {
            // Dropped scalars leave no trace — in particular not a word break, which is the
            // difference between الرحـــمن folding to الرحمن and to two words.
            guard let folded = fold(scalar) else { continue }

            if isWordScalar(folded) {
                word.append(folded)
            } else if !word.isEmpty {
                words.append(String(word))
                word = String.UnicodeScalarView()
            }
        }

        if !word.isEmpty { words.append(String(word)) }
        return words
    }

    /// The folded words joined by single spaces: the form written into an index column.
    public static func normalize(_ text: String) -> String {
        words(in: text).joined(separator: " ")
    }

    // MARK: The folding

    /// The letters that survive but are written more than one way.
    ///
    /// Mirrors `LETTER_FOLDING` in `Tools/CorpusBuilder/build_hadith_db.py`.
    static let letterFolding: [Unicode.Scalar: Unicode.Scalar] = [
        "\u{0623}": "\u{0627}",   // أ  alef with hamza above
        "\u{0625}": "\u{0627}",   // إ  alef with hamza below
        "\u{0622}": "\u{0627}",   // آ  alef with madda
        "\u{0671}": "\u{0627}",   // ٱ  alef wasla
        "\u{0629}": "\u{0647}",   // ة  ta marbuta, which readers type as ha
        "\u{0649}": "\u{064A}",   // ى  alef maqsura
        "\u{0624}": "\u{0648}",   // ؤ  waw with hamza
        "\u{0626}": "\u{064A}",   // ئ  yeh with hamza
    ]

    /// Letters by Unicode's reckoning, but not letters of the word a reader types (step 3).
    static let droppedLetters: Set<Unicode.Scalar> = [
        "\u{0640}",   // ـ  tatweel
        "\u{06E5}",   // ۥ  small waw
        "\u{06E6}",   // ۦ  small yeh
    ]

    /// The scalar as indexed, or `nil` when it is dropped without ending the word.
    static func fold(_ scalar: Unicode.Scalar) -> Unicode.Scalar? {
        guard scalar.properties.canonicalCombiningClass == .notReordered else { return nil }
        guard !droppedLetters.contains(scalar) else { return nil }
        return letterFolding[scalar] ?? scalar
    }

    /// Whether the scalar belongs inside a word. Everything else is a boundary — the same split
    /// FTS5's `unicode61` tokenizer makes when it indexes the folded text.
    static func isWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar)
    }
}
