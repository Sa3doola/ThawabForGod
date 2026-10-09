/// Removes the particles Arabic writes attached to the front of a word, so a search for
/// "الرحمن" also finds للرحمن (19:26), بالرحمن and والرحمن.
///
/// Works on words already folded by `ArabicNormalizer`. A prefix is an optional
/// conjunction (و ف) followed by an optional preposition (ب ك ل). The definite article stays:
/// بالرحمن → الرحمن, and ل before the article (لل, where the alef is not written) gives the
/// article back: للرحمن → الرحمن. So a stem compares with the words a reader types, and the
/// definite and indefinite forms stay apart (الكتاب is not كتاب).
///
/// For search only: the stems are indexed beside the words, never shown and never written
/// back into the text. **Quran only in v1** — the hadith index has no stem column, so hadith
/// search matches whole folded words as it always has.
public enum ArabicPrefixStemmer {
    /// Words this short keep their letters: ما، لا، وما، فلا، بما، لله are words, not prefixes.
    public static let maximumUnstemmedLetters = 3
    /// The shortest stem produced. With 3, "ما" or "لا" can never be the stem of a longer word
    /// (فلما → لما, never ما).
    public static let minimumStemLetters = 3

    private static let conjunctions: [Character] = ["\u{0648}", "\u{0641}"]          // و ف
    private static let prepositions: [Character] = ["\u{0628}", "\u{0643}", "\u{0644}"] // ب ك ل
    private static let lam: Character = "\u{0644}"
    private static let alef: Character = "\u{0627}"

    /// The stems of one folded word, without the word itself; empty when nothing is attached
    /// or the word is too short. Every reading is kept (وكتاب → كتاب and تاب), since the
    /// undotted text cannot tell which one is meant.
    public static func stems(of word: String) -> [String] {
        let letters = Array(word)
        guard letters.count > maximumUnstemmedLetters else { return [] }
        var stems: [String] = []
        func add(_ stem: [Character]) {
            let text = String(stem)
            if stem.count >= minimumStemLetters, text != word, !stems.contains(text) { stems.append(text) }
        }
        for conjunction in [nil] + conjunctions.map(Optional.some) {
            for preposition in [nil] + prepositions.map(Optional.some) where conjunction != nil || preposition != nil {
                let prefix = [conjunction, preposition].compactMap { $0 }
                guard letters.starts(with: prefix) else { continue }
                let rest = Array(letters.dropFirst(prefix.count))
                if preposition == lam, rest.first == lam {
                    // لل + X is ل + الX: give the article its alef back (needs 2+ letters after it).
                    if rest.count >= 3 { add([alef] + rest) }
                } else {
                    add(rest)
                }
            }
        }
        return stems
    }

    /// The stems of every word of a folded text (`ArabicNormalizer.normalize`), space separated,
    /// for the second index column.
    public static func stemText(_ normalizedText: String) -> String {
        normalizedText.split(separator: " ").flatMap { stems(of: String($0)) }.joined(separator: " ")
    }
}
