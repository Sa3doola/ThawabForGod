//
//  SurahNameGlyphTests.swift
//  ThawabForGodTests
//

import CoreText
import Testing
@testable import ThawabForGod

/// The table from chapter number to the character that draws its name.
///
/// The table is irregular by nature — see `SurahNameGlyph` — so the checks here are the ones that
/// would catch an edit that "tidied" it: one character per chapter, no two chapters sharing one,
/// and the spot checks that were verified glyph by glyph.
struct SurahNameGlyphTests {

    @Test func thereIsOneEntryPerChapter() {
        #expect(SurahNameGlyph.scalars.count == 114)
    }

    @Test func noTwoChaptersShareAGlyph() {
        #expect(Set(SurahNameGlyph.scalars).count == 114)
    }

    @Test(arguments: [
        (1, "!"),           // Al-Fatiha
        (33, "a"),          // Al-Ahzab — where the order stops being sequential
        (34, "A"),          // Saba
        (107, "\u{00AE}"),  // Al-Ma'un — U+00AD, the soft hyphen, is skipped
        (114, "\u{00B5}")   // An-Nas
    ])
    func spotChecks(surah: Int, expected: String) {
        #expect(SurahNameGlyph.glyph(forSurah: surah) == expected)
    }

    @Test func everyChapterIsASingleCharacter() {
        for surah in SurahNameGlyph.surahRange {
            #expect(SurahNameGlyph.glyph(forSurah: surah).count == 1, "surah \(surah)")
        }
    }

    /// Each character is one the face actually has a glyph for — a character it lacked would draw
    /// in a fallback font, which here means a bare "!" where a chapter title should be.
    @Test func theFaceDrawsEveryChapter() {
        FontRegistrar.registerBundledFonts()
        let font = CTFontCreateWithName(SurahNameGlyph.postScriptName as CFString, 12, nil)

        for surah in SurahNameGlyph.surahRange {
            let characters = Array(SurahNameGlyph.glyph(forSurah: surah).utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)

            #expect(
                CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count),
                "surah \(surah)"
            )
        }
    }
}
