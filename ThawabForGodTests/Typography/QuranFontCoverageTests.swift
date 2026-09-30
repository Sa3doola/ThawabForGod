//
//  QuranFontCoverageTests.swift
//  ThawabForGodTests
//

import CoreText
import Testing
@testable import ThawabForGod

/// Whether the default face can draw every character in the mushaf as shipped.
///
/// KFGQPC's Hafs face is encoded for one specific text. It has no glyphs for the open tanween
/// (U+08F0–U+08F2) some Uthmani editions use, among others, and a verse containing one would draw
/// that mark in a fallback font — a vowel in a different hand in the middle of a word, which is
/// the kind of error that reads as a misprint in the Quran rather than a bug in an app. So this
/// asks the font's own character map about every code point in all 6,236 verses: if a rebuild
/// ever switches the text to an edition the face was not made for, this is where it shows.
///
/// Amiri is not held to the same test. It covers everything KFGQPC does and more, so a text that
/// passes here passes for Amiri too.
struct QuranFontCoverageTests {

    private let repository = QuranRepository(database: CorpusDatabase(name: "quran"))

    @Test func theDefaultFaceHasAGlyphForEveryCharacterInTheText() async throws {
        FontRegistrar.registerBundledFonts()
        let font = CTFontCreateWithName(ReaderFont.kfgqpcHafs.postScriptName as CFString, 12, nil)

        var scalars = Set<Unicode.Scalar>()
        for surah in try await repository.surahs() {
            for verse in try await repository.verses(inSurah: surah.id) {
                scalars.formUnion(verse.text.unicodeScalars)
            }
        }

        let missing = scalars.filter { !Self.font(font, draws: $0) }
        #expect(
            missing.isEmpty,
            "KFGQPC has no glyph for \(missing.map { String($0.value, radix: 16) }.sorted())"
        )
    }

    /// The three this font is known to lack, asked about directly — the test above only proves
    /// they are absent from today's text, and this pins that the font check itself would catch
    /// them.
    @Test func theOpenTanweenAreNotInTheText() async throws {
        let openTanween: Set<Unicode.Scalar> = ["\u{08F0}", "\u{08F1}", "\u{08F2}"]

        for surah in try await repository.surahs() {
            for verse in try await repository.verses(inSurah: surah.id) {
                #expect(
                    openTanween.isDisjoint(with: verse.text.unicodeScalars),
                    "\(verse.id) uses an open tanween KFGQPC cannot draw"
                )
            }
        }
    }

    /// Numbers are drawn by the medallion faces; a digit already in the text would print the
    /// verse's number twice.
    @Test func noVerseCarriesItsOwnNumber() async throws {
        for surah in try await repository.surahs() {
            for verse in try await repository.verses(inSurah: surah.id) {
                #expect(
                    !verse.text.unicodeScalars.contains { $0.properties.numericType != nil },
                    "\(verse.id) has a digit in its text"
                )
            }
        }
    }

    private static func font(_ font: CTFont, draws scalar: Unicode.Scalar) -> Bool {
        let characters = Array(String(scalar).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        return CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
    }
}
