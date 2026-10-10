//
//  QuranTextFallbackTests.swift
//  ThawabForGodTests
//

import CoreGraphics
import CoreText
import Foundation
import SwiftUI
import Testing
@testable import ThawabForGod

/// The silent-letter mark (U+06DF) in the public Tanzil text, and the fallback that draws it (M5.0).
///
/// Five questions. Does `QuranAyahText.attributed` change nothing but the font (b)? Does the joining
/// rule that decides which stretches get the fallback face give the counts it was measured with (c)?
/// Are the two faces what the design says they are, by advance rather than by character map (d)? Is
/// the one path left alone really free of the mark (f)? And does the text hold no joiner characters,
/// the one case the joining rule would get wrong? The stored-text fingerprint (a) is in
/// `QuranStoredTextTests`.
///
/// Every test that needs Tanzil's text opens `QuranTestData.publicDatabase`, so none of them is
/// skipped where the full data is bundled.
struct QuranTextFallbackTests {

    private func publicCorpus() async throws -> QuranCorpus {
        try await QuranTestData.repository(QuranTestData.publicDatabase).loadCorpus(style: .madaniV2)
    }

    // MARK: (b) Only the renderer differs

    /// For all 6,236 ayahs: the characters read back are the stored characters, and the only thing
    /// set is a font, on exactly the stretches the fallback names.
    @Test func attributedChangesOnlyTheFontOfTheStretchesItNames() async throws {
        let amiri = ReaderFont.amiriQuran.font(size: 28)
        let ayahs = try await publicCorpus().ayahs
        #expect(ayahs.count == 6236)

        var mismatches: [String] = []
        for ayah in ayahs {
            let text = ayah.text
            let result = QuranAyahText.attributed(text, face: .kfgqpcHafs, scaledSize: 28)

            // Scalars, not `String ==`: a comparison that forgave a normalisation would prove nothing.
            if Array(String(result.characters).unicodeScalars) != Array(text.unicodeScalars) {
                mismatches.append("\(ayah.id) changed its characters")
            }

            // Whole-string equality catches what the font check cannot: a kern, a baseline offset or a
            // colour left on a run. Clearing the font over the whole copy must leave the plain string.
            var cleared = result
            cleared[cleared.startIndex..<cleared.endIndex].font = nil
            if cleared != AttributedString(text) {
                mismatches.append("\(ayah.id) carries an attribute other than its font")
            }

            var drawnInAmiri = Set<Int>()
            for run in result.runs {
                guard let font = run.attributes[AttributeScopes.SwiftUIAttributes.FontAttribute.self] else { continue }
                if font == amiri {
                    drawnInAmiri.formUnion(Self.characterOffsets(of: run.range, in: result))
                } else {
                    mismatches.append("\(ayah.id) has a run in a font other than Amiri")
                }
            }

            let named = Self.characterOffsets(of: QuranTextFallback.ranges(in: text), in: text)
            if drawnInAmiri != named {
                mismatches.append("\(ayah.id) sets Amiri on the wrong stretches")
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(5))")
    }

    /// The three cases that must change nothing: a face other than Hafs, Hafs unregistered, and a
    /// text with no mark. Each returns the input exactly, with no attribute at all on any run.
    @Test func theThreeNoOpCasesNameNoFont() async throws {
        let corpus = try await publicCorpus()
        let marked = try #require(corpus.ayah(VerseReference(surah: 2, verse: 6))?.text)
        let unmarked = corpus.basmala
        #expect(QuranTextFallback.isNeeded(in: marked))
        #expect(!QuranTextFallback.isNeeded(in: unmarked))

        let cases: [(name: String, result: AttributedString, input: String)] = [
            ("the face is Amiri", QuranAyahText.attributed(marked, face: .amiriQuran, scaledSize: 28), marked),
            ("Hafs is not registered", QuranAyahText.attributed(marked, face: .kfgqpcHafs, scaledSize: 28, hafsIsRegistered: false), marked),
            ("the text has no mark", QuranAyahText.attributed(unmarked, face: .kfgqpcHafs, scaledSize: 28), unmarked),
        ]
        for (name, result, input) in cases {
            let runsWithFont = result.runs.filter { $0.attributes[AttributeScopes.SwiftUIAttributes.FontAttribute.self] != nil }
            #expect(runsWithFont.isEmpty, "\(name) set a font")
            // Scalars first, as above; then the whole value, attributes included.
            #expect(Array(String(result.characters).unicodeScalars) == Array(input.unicodeScalars), "\(name) changed the characters")
            #expect(result == AttributedString(input), "\(name) carries an attribute")
        }
    }

    /// The joining rule treats format characters as transparent, which is wrong for a joiner. So the
    /// public text must give it no occasion to matter: no ZWNJ (U+200C) and no ZWJ (U+200D) anywhere.
    @Test func thePublicTextHasNoJoinerCharacters() async throws {
        var offending: [String] = []
        for ayah in try await publicCorpus().ayahs {
            if ayah.text.unicodeScalars.contains(where: { $0 == "\u{200C}" || $0 == "\u{200D}" }) {
                offending.append("\(ayah.id)")
            }
        }
        #expect(offending.isEmpty, "\(offending.prefix(5))")
    }

    // MARK: (c) The joining rule

    /// The counts the rule was measured with: 3,988 occurrences in 2,240 ayahs, 27 of them joined,
    /// and by base letter. The ya and alif maqsura are the code points the data holds (U+064A and
    /// U+0649), which the note expects.
    ///
    /// The first measurement said 30 joined, and it was the measurement that was wrong. It counted
    /// any character in a letter category as joining, which took in U+06E5, the small waw: a
    /// modifier letter that joins nothing. Three alifs follow one (4:135, 18:16, 43:13) and stand
    /// free, since the letter before the small waw is a waw. They are named cases below.
    @Test func occurrencesMatchTheMeasuredCounts() async throws {
        var total = 0
        var ayahsWithMark = 0
        var joined = 0
        var tally: [String: Int] = [:]
        for ayah in try await publicCorpus().ayahs {
            let occurrences = QuranTextFallback.occurrences(in: ayah.text)
            if !occurrences.isEmpty { ayahsWithMark += 1 }
            total += occurrences.count
            for occurrence in occurrences {
                if occurrence.isJoined { joined += 1 }
                let key = "\(Self.hex(occurrence.base))/\(occurrence.isJoined ? "joined" : "free")"
                tally[key, default: 0] += 1
            }
        }
        #expect(total == 3988)
        #expect(ayahsWithMark == 2240)
        #expect(joined == 27)
        #expect(total - joined == 3961)
        #expect(tally == [
            "627/free": 3705,
            "648/free": 255,
            "627/joined": 17,
            "64A/joined": 10,
            "649/free": 1,
        ])
    }

    /// The named cases, each located by its ayah and the word in it that carries the mark. The last
    /// three are the alifs after a small waw (U+06E5), which joins nothing: free, though a rule that
    /// took every letter-like character for a joining one would call them joined.
    @Test(arguments: [
        (VerseReference(surah: 2, verse: 6), "كَفَرُوا۟", false),
        (VerseReference(surah: 2, verse: 5), "أُو۟لَٰٓئِكَ", false),
        (VerseReference(surah: 2, verse: 259), "مِا۟ئَةَ", true),
        (VerseReference(surah: 3, verse: 144), "أَفَإِي۟ن", true),
        (VerseReference(surah: 51, verse: 47), "بِأَيْي۟دٍ", true),
        // Spelled out: Tanzil stores the shadda before the fatha (U+0651 U+064E), and a tool that
        // normalises this file would silently swap them into canonical order.
        (VerseReference(surah: 6, verse: 34), "\u{0646}\u{0651}\u{064E}\u{0628}\u{064E}\u{0625}\u{0650}\u{0649}\u{06DF}", false),
        (VerseReference(surah: 4, verse: 135), "تَلْوُۥٓا۟", false),
        (VerseReference(surah: 18, verse: 16), "فَأْوُۥٓا۟", false),
        (VerseReference(surah: 43, verse: 13), "لِتَسْتَوُۥا۟", false),
    ])
    func namedWordsAreJoinedOrFree(_ reference: VerseReference, word: String, joined: Bool) async throws {
        let corpus = try await publicCorpus()
        let text = try #require(corpus.ayah(reference)?.text)
        // By its text, not by position: an ayah may hold several marked words (6:34 has one before
        // this one). Scalars, so that a normalised look-alike is not taken for the stored word.
        let occurrence = try #require(
            QuranTextFallback.occurrences(in: text).first { Array(text[$0.word].unicodeScalars) == Array(word.unicodeScalars) },
            "\(reference) has no marked word \(word)"
        )
        #expect(occurrence.isJoined == joined, "\(reference)")
    }

    /// The invariants that hold whichever way `usesClusterRuns` is set.
    @Test func rangesAndOccurrencesAgreeInEveryAyah() async throws {
        var mismatches: [String] = []
        for ayah in try await publicCorpus().ayahs {
            let text = ayah.text
            let occurrences = QuranTextFallback.occurrences(in: text)
            let ranges = QuranTextFallback.ranges(in: text)

            for (earlier, later) in zip(ranges, ranges.dropFirst()) where !(earlier.upperBound <= later.lowerBound) {
                mismatches.append("\(ayah.id) ranges are not ascending and disjoint")
            }

            for occurrence in occurrences {
                let containing = ranges.filter {
                    $0.lowerBound <= occurrence.cluster.lowerBound && occurrence.cluster.upperBound <= $0.upperBound
                }
                if containing.count != 1 {
                    mismatches.append("\(ayah.id) has a mark in \(containing.count) ranges")
                }
                if occurrence.isJoined && !ranges.contains(occurrence.word) {
                    mismatches.append("\(ayah.id) has a joined mark outside a word-sized range")
                }
            }

            for range in ranges where !occurrences.contains(where: { $0.cluster == range || $0.word == range }) {
                mismatches.append("\(ayah.id) has a range that is neither a cluster nor a word")
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(5))")
    }

    /// Only when cluster runs are on: a word with no joined mark is drawn as one run per mark, the
    /// free-standing base and its mark. Disabled, not passed, when `usesClusterRuns` is false.
    @Test(.enabled(if: QuranTextFallback.usesClusterRuns, "cluster runs are off: every affected word is set whole"))
    func freeStandingMarksGetTheirOwnRunWhenClusterRunsAreOn() async throws {
        var mismatches: [String] = []
        for ayah in try await publicCorpus().ayahs {
            let text = ayah.text
            let occurrences = QuranTextFallback.occurrences(in: text)
            let ranges = QuranTextFallback.ranges(in: text)
            for occurrence in occurrences where !occurrences.contains(where: { $0.word == occurrence.word && $0.isJoined }) {
                if !ranges.contains(occurrence.cluster) {
                    mismatches.append("\(ayah.id) has a free mark without a cluster-sized run")
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(5))")
    }

    // MARK: (d) The fonts are what the design says they are

    /// **Failure here means the fallback is no longer needed.** If KFGQPC Hafs ever draws U+06DF as
    /// an anchored mark, the stretch set in Amiri does nothing useful, and `QuranTextFallback` should
    /// be removed. A cmap check cannot see this: Hafs has a glyph for the scalar either way. Only the
    /// advance tells the spacing glyph from the mark.
    @Test func hafsDrawsTheSilentLetterMarkWithAnAdvance() throws {
        FontRegistrar.registerBundledFonts()
        let hafs = CTFontCreateWithName(ReaderFont.kfgqpcHafs.postScriptName as CFString, 100, nil)
        let glyph = try #require(Self.glyph(hafs, "\u{06DF}"))
        #expect(
            Self.advance(hafs, glyph) > 0,
            "Hafs draws U+06DF with no advance: the fallback has become unnecessary and QuranTextFallback should go"
        )
    }

    /// The sukun and the two other marks Hafs draws as marks. Their glyphs must exist, or a zero
    /// advance would be a missing glyph rather than a mark.
    @Test func hafsDrawsTheSukunAndTheOtherMarksWithoutAnAdvance() throws {
        FontRegistrar.registerBundledFonts()
        let hafs = CTFontCreateWithName(ReaderFont.kfgqpcHafs.postScriptName as CFString, 100, nil)
        let marks: [Unicode.Scalar] = ["\u{0652}", "\u{06E0}", "\u{06E1}"]
        for scalar in marks {
            let glyph = try #require(Self.glyph(hafs, scalar))
            #expect(Self.advance(hafs, glyph) == 0, "Hafs gives U+\(Self.hex(scalar)) an advance")
        }
    }

    /// **Failure here means the fallback face no longer draws the mark as a mark.** Amiri Quran must
    /// set U+06DF with no advance, which is what lets the fallback stand in for the spacing glyph.
    @Test func amiriDrawsTheSilentLetterMarkWithoutAnAdvance() throws {
        FontRegistrar.registerBundledFonts()
        let amiri = CTFontCreateWithName(ReaderFont.amiriQuran.postScriptName as CFString, 100, nil)
        let glyph = try #require(Self.glyph(amiri, "\u{06DF}"))
        #expect(
            Self.advance(amiri, glyph) == 0,
            "Amiri Quran draws U+06DF with an advance: the fallback face no longer draws the mark as a mark"
        )
    }

    /// Whole words are set in Amiri, so it must cover every scalar inside every fallback range.
    @Test func amiriHasAGlyphForEveryScalarInEveryFallbackRange() async throws {
        FontRegistrar.registerBundledFonts()
        let amiri = CTFontCreateWithName(ReaderFont.amiriQuran.postScriptName as CFString, 12, nil)
        var missing = Set<Unicode.Scalar>()
        for ayah in try await publicCorpus().ayahs {
            for range in QuranTextFallback.ranges(in: ayah.text) {
                for scalar in ayah.text[range].unicodeScalars where !Self.font(amiri, draws: scalar) {
                    missing.insert(scalar)
                }
            }
        }
        #expect(missing.isEmpty, "Amiri has no glyph for \(missing.map { String($0.value, radix: 16) }.sorted())")
    }

    // MARK: (f) The paths left alone are safe

    /// The basmala is set in Hafs without the fallback, so it must not hold the mark.
    @Test func theBasmalaHasNoSilentLetterMark() async throws {
        let basmala = try await publicCorpus().basmala
        #expect(!basmala.isEmpty)
        #expect(!basmala.unicodeScalars.contains("\u{06DF}"))
    }

    /// No ayah of the full build holds the mark, so Mushaf mode's Unicode path never needs the
    /// fallback. Guarded: the full build is git-ignored.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func noAyahOfTheFullDatabaseNeedsTheFallback() async throws {
        let ayahs = try await QuranTestData.repository(QuranTestData.fullDatabase).loadCorpus(style: .madaniV2).ayahs
        #expect(ayahs.count == 6236)
        let needed = ayahs.filter { QuranTextFallback.isNeeded(in: $0.text) }.map(\.id)
        #expect(needed.isEmpty, "\(needed.prefix(5))")
    }

    // MARK: Helpers

    /// `Character` offsets of `ranges` in `text`, as a set. Comparing offsets, not indices or run
    /// boundaries, keeps the test independent of how adjacent runs happen to be split.
    private static func characterOffsets(of ranges: [Range<String.Index>], in text: String) -> Set<Int> {
        var offsets = Set<Int>()
        for range in ranges {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let end = text.distance(from: text.startIndex, to: range.upperBound)
            offsets.formUnion(start..<end)
        }
        return offsets
    }

    private static func characterOffsets(of range: Range<AttributedString.Index>, in string: AttributedString) -> Set<Int> {
        let start = string.characters.distance(from: string.startIndex, to: range.lowerBound)
        let end = string.characters.distance(from: string.startIndex, to: range.upperBound)
        return Set(start..<end)
    }

    private static func hex(_ scalar: Unicode.Scalar) -> String {
        String(scalar.value, radix: 16, uppercase: true)
    }

    private static func glyph(_ font: CTFont, _ scalar: Unicode.Scalar) -> CGGlyph? {
        let characters = Array(String(scalar).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        guard CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count) else { return nil }
        return glyphs[0]
    }

    private static func advance(_ font: CTFont, _ glyph: CGGlyph) -> CGFloat {
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, [glyph], &advance, 1)
        return advance.width
    }

    private static func font(_ font: CTFont, draws scalar: Unicode.Scalar) -> Bool {
        glyph(font, scalar) != nil
    }
}
