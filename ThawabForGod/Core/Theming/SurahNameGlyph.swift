//
//  SurahNameGlyph.swift
//  ThawabForGod
//

import Foundation

// TODO(license): confirm redistribution rights before App Store release. "Quran karim 114" is
// © elharrakfonts.com with "All Rights Reserved" in its own name table, and no licence to
// redistribute it has been found.

/// Which character draws which chapter's name in the "Quran karim 114" face.
///
/// The face has no Arabic letters at all. Each of 114 ASCII and Latin-1 characters is a single
/// glyph holding one chapter's whole calligraphic "سورة …" title, so a heading is one character
/// rather than a word set in a script face — which is what lets it be drawn the way a printed
/// mushaf draws it.
///
/// **The table is not a range.** It runs `!` through `@` for the first 32 chapters and then
/// interleaves upper and lower case in an order that follows the font's author rather than any
/// encoding, skips U+00AD (soft hyphen, which text systems are allowed to hide), and ends at
/// U+00B5. Every entry was checked against the glyph it draws; a formula that "simplified" it
/// would put the wrong name over a chapter, silently.
nonisolated enum SurahNameGlyph {

    /// "Quran karim 114" in the file's own name table; CoreText registers it with its spaces as
    /// hyphens — see `AyahMarkerStyle.postScriptName` — and this is the name it reports back.
    static let postScriptName = "Quran-karim-114"

    /// Chapter N is at index N − 1.
    static let scalars: [UInt32] = [
        0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A,   //   1–10
        0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x32, 0x33, 0x34,   //  11–20
        0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E,   //  21–30
        0x3F, 0x40, 0x61, 0x41, 0x62, 0x42, 0x63, 0x43, 0x64, 0x44,   //  31–40
        0x45, 0x65, 0x46, 0x66, 0x67, 0x47, 0x48, 0x68, 0x49, 0x69,   //  41–50
        0x4A, 0x6A, 0x4B, 0x6B, 0x6C, 0x4C, 0x4D, 0x6D, 0x6E, 0x4E,   //  51–60
        0x4F, 0x6F, 0x70, 0x50, 0x51, 0x71, 0x52, 0x72, 0x73, 0x53,   //  61–70
        0x74, 0x54, 0x75, 0x55, 0x76, 0x56, 0x57, 0x77, 0x78, 0x58,   //  71–80
        0x79, 0x59, 0x5A, 0x7A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60,   //  81–90
        0x7B, 0x7C, 0x7D, 0x7E, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6,   //  91–100
        0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAE, 0xAF, 0xB0, 0xB1,   // 101–110
        0xB2, 0xB3, 0xB4, 0xB5                                        // 111–114
    ]

    static let surahRange = 1...114

    /// The one-character string that draws chapter `surah`'s name.
    ///
    /// Traps outside 1…114. Every caller holds a chapter number that came out of the corpus, so a
    /// number outside the mushaf is a bug in the caller and not an input to recover from — and
    /// the recovery on offer would be drawing some other chapter's name.
    static func glyph(forSurah surah: Int) -> String {
        precondition(surahRange.contains(surah), "No chapter \(surah) in the mushaf")
        // Every value in the table is a valid scalar, so the unwrap cannot fail for any index
        // the precondition lets through.
        return String(Character(Unicode.Scalar(scalars[surah - 1])!))
    }
}
