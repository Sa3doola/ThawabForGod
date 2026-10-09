import ArabicText
import Testing

/// The folding rule, case by case. Ported from Mushaf's `ArabicSearchNormalizerTests`, with the
/// cases where the reconciled rule (QURAN_MIGRATION_PLAN.md, T3) answers differently marked.
struct ArabicNormalizerTests {

    @Test(arguments: [
        // Uthmani Hafs text (KFGQPC) folds to plain letters.
        ("بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ", "بسم الله الرحمن الرحيم"),
        // The superscript alef is dropped, not turned into a letter.
        ("ٱلۡحَمۡدُ لِلَّهِ رَبِّ ٱلۡعَٰلَمِينَ", "الحمد لله رب العلمين"),
        // Imlaei (already undotted) only has its letter forms folded.
        ("إن الذين آمنوا", "ان الذين امنوا"),
        // Tanzil Uthmani, the text the fallback build indexes beside Simple Clean.
        ("لَا تَأْخُذُهُۥ سِنَةٌ وَلَا نَوْمٌ", "لا تاخذه سنه ولا نوم"),
    ])
    func foldsAyahText(_ input: String, _ expected: String) {
        #expect(ArabicNormalizer.normalize(input) == expected)
    }

    @Test(arguments: [
        ("أإآٱا", "ااااا"),
        ("مكة", "مكه"),
        ("على", "علي"),
        ("مؤمن", "مومن"),
        ("سئل", "سيل"),
        ("الـرحمـن", "الرحمن"),
        ("۞ قل", "قل"),
        ("سجدة ۩", "سجده"),
    ])
    func foldsLetterForms(_ input: String, _ expected: String) {
        #expect(ArabicNormalizer.normalize(input) == expected)
    }

    /// The two letter-like Quranic marks Unicode files as letters (Lm), so the combining-class
    /// rule alone would keep them and بهۥ would be a different word from به.
    @Test(arguments: [
        ("بِهِۦ", "به"),
        ("لَهُۥ", "له"),
        ("عَلَيۡهِۦ", "عليه"),
    ])
    func dropsSmallWawAndSmallYeh(_ input: String, _ expected: String) {
        #expect(ArabicNormalizer.normalize(input) == expected)
    }

    /// ۝ ۞ ۩ end a word rather than vanishing inside it. Mushaf's rule dropped them, which would
    /// have glued قل۞هو into one word; in the corpora they always sit beside a space or at a
    /// word's end, so the indexes are the same either way.
    @Test(arguments: [
        ("قل۞هو", ["قل", "هو"]),
        ("يَسۡجُدُونَۤ۩", ["يسجدون"]),
        ("آية\u{06DD}١٢", ["ايه", "١٢"]),
    ])
    func quranicSignsEndAWord(_ input: String, _ expected: [String]) {
        #expect(ArabicNormalizer.words(in: input) == expected)
    }

    /// Composed and decomposed spellings of one letter fold together, as they do in Python.
    @Test(arguments: [
        ("\u{0627}\u{0653}", "ا"),    // alef + madda
        ("\u{0648}\u{0654}", "و"),    // waw + hamza above
        ("\u{064A}\u{0654}", "ي"),    // yeh + hamza above
        ("\u{06C1}\u{0654}", "\u{06C2}"),  // heh goal + hamza above composes, and is not folded
    ])
    func composesBeforeFolding(_ input: String, _ expected: String) {
        #expect(ArabicNormalizer.normalize(input) == expected)
    }

    @Test func collapsesAndTrimsWhitespace() {
        #expect(ArabicNormalizer.normalize("  الله \n\t اكبر  ") == "الله اكبر")
        #expect(ArabicNormalizer.normalize("   ") == "")
        // A word made only of marks or signs disappears without leaving a double space.
        #expect(ArabicNormalizer.normalize("قل ۞ هو") == "قل هو")
    }

    /// Every word is letters and digits only — what keeps a typed query from reaching FTS5 as
    /// syntax. Mushaf's rule kept punctuation inside a word; this one splits on it.
    @Test func splitsOnEverythingThatIsNotALetterOrDigit() {
        #expect(ArabicNormalizer.words(in: "\"الحمد لله\" *") == ["الحمد", "لله"])
        #expect(ArabicNormalizer.words(in: "Al-Baqarah") == ["Al", "Baqarah"])
        #expect(ArabicNormalizer.words(in: "الله_اكبر") == ["الله", "اكبر"])
        #expect(ArabicNormalizer.words(in: "قال، ثم؛ قال؟") == ["قال", "ثم", "قال"])
    }

    @Test func leavesOtherScriptsAndDigitsAlone() {
        #expect(ArabicNormalizer.normalize("Mercy 255") == "Mercy 255")
        #expect(ArabicNormalizer.normalize("٢٥٥") == "٢٥٥")
        #expect(ArabicNormalizer.normalize("۲۵۵") == "۲۵۵")
    }

    @Test(arguments: ["بِسۡمِ ٱللَّهِ", "مَّقۡبُوضَةٞۖ", "يَٰٓأَيُّهَا", "قُرۡءَانٗا", "بِإِذْنِهِۦ"])
    func isIdempotent(_ input: String) {
        let once = ArabicNormalizer.normalize(input)
        #expect(ArabicNormalizer.normalize(once) == once)
    }
}
