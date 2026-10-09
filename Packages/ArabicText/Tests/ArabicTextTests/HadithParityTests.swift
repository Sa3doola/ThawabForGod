import ArabicText
import Foundation
import Testing

/// The Swift fold against the Python one that built `hadith.sqlite`'s index.
///
/// The hadith index is folded at build time by `normalize()` in
/// `Tools/CorpusBuilder/build_hadith_db.py`; a hadith query is folded at search time by
/// `ArabicNormalizer`. Every probe in `Fixtures/hadith-parity.jsonl` was folded by the Python and
/// recorded by `Tools/CorpusBuilder/export_normalize_parity.py`; this folds the same probe with the
/// Swift and requires the same words.
///
/// The one sanctioned difference is the small waw and small yeh, which Swift drops and Python keeps:
/// probes containing them are marked `quranOnly` and must differ by exactly those letters. The
/// export script refuses to run if either appears in the hadith text, so the difference cannot
/// reach a word the hadith index holds.
struct HadithParityTests {

    struct Probe: Decodable, Sendable, CustomTestStringConvertible {
        let input: String
        let python: String
        let quranOnly: Bool

        var testDescription: String {
            input.unicodeScalars.map { $0.isASCII ? String($0) : String(format: "U+%04X", $0.value) }
                .joined(separator: " ")
        }
    }

    static let probes: [Probe] = {
        guard
            let url = Bundle.module.url(
                forResource: "hadith-parity", withExtension: "jsonl", subdirectory: "Fixtures"
            ),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }

        let decoder = JSONDecoder()
        return text.split(separator: "\n").compactMap {
            try? decoder.decode(Probe.self, from: Data($0.utf8))
        }
    }()

    @Test func theFixtureIsThere() {
        // A missing or unreadable fixture would otherwise pass every parameterised case below by
        // having none.
        #expect(Self.probes.count >= 150)
    }

    @Test(arguments: probes.filter { !$0.quranOnly })
    func swiftFoldsLikePython(_ probe: Probe) {
        #expect(ArabicNormalizer.normalize(probe.input) == probe.python)
    }

    @Test(arguments: probes.filter(\.quranOnly))
    func quranOnlyProbesDifferByTheSmallLettersAlone(_ probe: Probe) {
        let smallLetters: Set<Character> = ["\u{06E5}", "\u{06E6}"]
        let pythonWithoutThem = probe.python
            .split(separator: " ")
            .map { String($0.filter { !smallLetters.contains($0) }) }
            .filter { !$0.isEmpty }

        #expect(ArabicNormalizer.words(in: probe.input) == pythonWithoutThem)
    }
}
