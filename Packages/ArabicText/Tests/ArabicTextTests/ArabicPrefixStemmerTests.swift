import ArabicText
import Testing

struct ArabicPrefixStemmerTests {
    @Test(arguments: [
        ("للرحمن", ["الرحمن"]),             // 19:26: ل before the article gives the alef back
        ("بالرحمن", ["الرحمن"]),
        ("والرحمن", ["الرحمن"]),
        ("فالله", ["الله"]),
        ("بالله", ["الله"]),
        ("وللدار", ["للدار", "الدار"]),
        ("وقال", ["قال"]),
        ("فقالوا", ["قالوا"]),
        ("كالعهن", ["العهن"]),
        ("وبالوالدين", ["بالوالدين", "الوالدين"]),
        ("فلما", ["لما"]),                    // never ما
        ("وكتاب", ["كتاب", "تاب"]),          // the undotted text cannot tell: both kept
    ])
    func stripsAttachedParticles(_ word: String, _ stems: [String]) {
        #expect(ArabicPrefixStemmer.stems(of: word) == stems, "\(word)")
    }

    /// Three letters or fewer are left alone, and no stem is shorter than three letters.
    @Test(arguments: ["ما", "لا", "وما", "فلا", "بما", "كما", "لله", "لكم", "ولا", "قال", "الله", "الرحمن", "رحمن", "من"])
    func leavesShortAndBareWordsAlone(_ word: String) {
        #expect(ArabicPrefixStemmer.stems(of: word).isEmpty, "\(word)")
    }

    @Test func stemsAreNeverShort() {
        for word in ["فلما", "ولما", "بكم", "ولله", "فلله", "وبها", "فبما"] {
            #expect(ArabicPrefixStemmer.stems(of: word).allSatisfy { $0.count >= ArabicPrefixStemmer.minimumStemLetters }, "\(word)")
        }
        #expect(ArabicPrefixStemmer.stems(of: "ولله") == ["لله"], "not اله")
    }

    @Test func stemTextHoldsOnlyStrippedWords() {
        let text = ArabicNormalizer.normalize("فقولي اني نذرت للرحمن صوما فلن اكلم اليوم انسيا")
        #expect(ArabicPrefixStemmer.stemText(text) == "قولي الرحمن")
    }
}
