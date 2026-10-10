//
//  QuranFontCoverageTests.swift
//  ThawabForGodTests
//

import CoreText
import Testing
@testable import ThawabForGod

/// Whether the KFGQPC Hafs face can draw every character of the text it is asked to draw.
///
/// KFGQPC's Hafs face is encoded for one specific text. It has no glyphs for the open tanween
/// (U+08F0–U+08F2) some Uthmani editions use, among others, and a verse containing one would draw
/// that mark in a fallback font — a vowel in a different hand in the middle of a word, which reads
/// as a misprint in the Quran rather than a bug in an app. So this asks the font's own character
/// map about every code point in all 6,236 ayahs: if a rebuild ever switches the text to an
/// edition the face was not made for, this is where it shows.
///
/// Both builds' texts — Tanzil's Uthmani in every clone, QUL's Hafs where the full data was built —
/// since the separated reader sets either in this face. Amiri covers everything KFGQPC does and
/// more, so a text that passes here passes for Amiri too.
struct QuranFontCoverageTests {

    static let databases = [QuranTestData.publicDatabase] + (QuranTestData.hasFullData ? [QuranTestData.fullDatabase] : [])

    private func ayahs(_ database: QuranDatabase) async throws -> [Ayah] {
        try await QuranTestData.repository(database).loadCorpus(style: .madaniV2).ayahs
    }

    @Test(arguments: databases)
    func theFaceHasAGlyphForEveryCharacterInTheText(_ database: QuranDatabase) async throws {
        FontRegistrar.registerBundledFonts()
        let font = CTFontCreateWithName(ReaderFont.kfgqpcHafs.postScriptName as CFString, 12, nil)

        var scalars = Set<Unicode.Scalar>()
        for ayah in try await ayahs(database) {
            scalars.formUnion(ayah.text.unicodeScalars)
            scalars.formUnion(ayah.marker.unicodeScalars)
        }

        let missing = scalars.filter { !Self.font(font, draws: $0) }
        #expect(missing.isEmpty, "KFGQPC has no glyph for \(missing.map { String($0.value, radix: 16) }.sorted())")
    }

    /// The three this font is known to lack, asked about directly — the test above only proves
    /// they are absent from today's text, and this pins that the font check itself would catch them.
    @Test(arguments: databases)
    func theOpenTanweenAreNotInTheText(_ database: QuranDatabase) async throws {
        let openTanween: Set<Unicode.Scalar> = ["\u{08F0}", "\u{08F1}", "\u{08F2}"]

        for ayah in try await ayahs(database) {
            #expect(openTanween.isDisjoint(with: ayah.text.unicodeScalars), "\(ayah.id) uses an open tanween KFGQPC cannot draw")
        }
    }

    /// The verse number is the end marker, drawn after the text; a digit already in the text would
    /// print it twice.
    @Test(arguments: databases)
    func noAyahCarriesItsOwnNumber(_ database: QuranDatabase) async throws {
        for ayah in try await ayahs(database) {
            #expect(!ayah.text.unicodeScalars.contains { $0.properties.numericType != nil }, "\(ayah.id) has a digit in its text")
        }
    }

    private static func font(_ font: CTFont, draws scalar: Unicode.Scalar) -> Bool {
        let characters = Array(String(scalar).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        return CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
    }
}
