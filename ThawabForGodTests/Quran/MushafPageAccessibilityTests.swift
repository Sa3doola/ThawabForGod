//
//  MushafPageAccessibilityTests.swift
//  ThawabForGodTests
//

import Testing
@testable import ThawabForGod

/// The VoiceOver grouping of a Mushaf page: one element per ayah, however many lines it spans.
/// Mushaf only covered this in UI tests; these are the unit-level equivalents of
/// `MushafPageElement.elements(on:)` and `words(of:on:)`.
struct MushafPageAccessibilityTests {

    /// A page built by hand: a surah header, a basmala, then 2:1 across two text lines, with 2:2
    /// starting on the second.
    static func handBuiltPage() -> MushafPage {
        let lines = [
            MushafLine(number: 1, kind: .surahHeader(2), segments: [], isCentered: true),
            MushafLine(number: 2, kind: .basmala, segments: [], isCentered: true),
            MushafLine(number: 3, kind: .text, segments: [
                Segment(surah: 2, verse: 1, words: ["a", "b"], endsAyah: false,
                        glyphs: ["\u{FB51}", "\u{FB52}"]),
            ], isCentered: false),
            MushafLine(number: 4, kind: .text, segments: [
                Segment(surah: 2, verse: 1, words: ["c"], endsAyah: true,
                        glyphs: ["\u{FB53}"], markerGlyph: "\u{FB54}", markerText: "\u{0661}"),
                Segment(surah: 2, verse: 2, words: ["d"], endsAyah: false,
                        glyphs: ["\u{FB55}"]),
            ], isCentered: false),
        ]
        return MushafPage(number: 2, juz: 1, lines: lines)
    }

    @Test func eachAyahIsOneElementInReadingOrder() {
        let elements = MushafPageElement.elements(on: Self.handBuiltPage())
        #expect(elements == [.surahHeader(2), .basmala(line: 2), .ayah(VerseReference(surah: 2, verse: 1)), .ayah(VerseReference(surah: 2, verse: 2))])
    }

    @Test func wordsJoinAcrossLinesAndIgnoreGlyphCodes() {
        let page = Self.handBuiltPage()
        #expect(MushafPageElement.words(of: VerseReference(surah: 2, verse: 1), on: page) == "a b c")
        #expect(MushafPageElement.words(of: VerseReference(surah: 2, verse: 2), on: page) == "d")
        #expect(MushafPageElement.words(of: VerseReference(surah: 2, verse: 3), on: page) == "")
    }

    /// Every ayah on a real printed page is one element, exactly once.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func everyAyahOnPage50IsOneElement() async throws {
        let corpus = try await QuranTestData.repository(QuranTestData.fullDatabase).loadCorpus(style: .madaniV2)
        let page = try #require(corpus.page(50))
        let elements = MushafPageElement.elements(on: page)
        for ayah in page.ayahs {
            #expect(elements.filter { $0 == .ayah(ayah) }.count == 1, "\(ayah)")
        }
        let ayahElements = elements.compactMap { element -> VerseReference? in
            if case .ayah(let reference) = element { return reference }
            return nil
        }
        #expect(Set(ayahElements) == Set(page.ayahs))
        #expect(ayahElements.count == page.ayahs.count)
    }
}
