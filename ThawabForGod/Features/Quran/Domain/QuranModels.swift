//
//  QuranModels.swift
//  ThawabForGod
//

import Foundation

// Ported from Mushaf's `QuranModels` (QURAN_MIGRATION_PLAN.md, M3). Mushaf's `AyahID` is
// `VerseReference` here (T7), in `Shared/` because the widgets and `DeepLink` need it too.

nonisolated enum RevelationPlace: String, Codable, Sendable {
    case makkah, madinah
}

nonisolated struct Surah: Identifiable, Hashable, Sendable {
    let number: Int
    let arabicName: String
    let englishName: String
    let ayahCount: Int
    let revelationPlace: RevelationPlace
    /// Mushaf page where the surah starts; `nil` in a build without the printed layout (the Tanzil
    /// fallback), where a page number would name a page of a different print.
    let startPage: Int?
    /// What draws the surah's Mushaf header in `QuranFace.surahHeader` (one code point), from QUL's
    /// ligature table. `nil` if the table has no entry, and always in the Tanzil fallback.
    var headerGlyph: String? = nil
    /// Ligature string ("surah002") that draws the calligraphic name in `QuranFace.surahName`.
    var nameGlyph: String? = nil

    var id: Int { number }

    /// Al-Fatihah's basmala is its first ayah, and At-Tawbah has none.
    var hasBasmalaLine: Bool { number != 1 && number != 9 }

    func name(in language: AppLanguage) -> String {
        language == .arabic ? arabicName : englishName
    }
}

nonisolated struct Ayah: Identifiable, Hashable, Sendable {
    let id: VerseReference
    /// Full text without the trailing ayah number.
    let text: String
    /// The Mushaf page it starts on; `nil` in the Tanzil fallback (see `Surah.startPage`).
    let page: Int?
    let juz: Int
    /// The end marker's Hafs text (the ayah number in Arabic-Indic digits; KFGQPC Hafs draws it
    /// as the ornamented end-of-ayah sign).
    var marker: String = ""
}

nonisolated struct MushafPage: Identifiable, Hashable, Sendable {
    let number: Int
    let juz: Int
    let lines: [MushafLine]

    var id: Int { number }

    /// First ayah that has words on this page.
    var firstAyah: VerseReference? {
        for line in lines {
            if let segment = line.segments.first(where: { !$0.words.isEmpty }) { return segment.reference }
        }
        return nil
    }

    var ayahs: [VerseReference] {
        var result: [VerseReference] = []
        for segment in lines.flatMap(\.segments) where result.last != segment.reference {
            result.append(segment.reference)
        }
        return result
    }
}

nonisolated struct MushafLine: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case surahHeader(Int)
        case basmala
        case text
    }

    /// 1-based position on the page.
    let number: Int
    let kind: Kind
    let segments: [Segment]
    let isCentered: Bool
}

extension MushafLine: Identifiable {
    nonisolated var id: Int { number }
}

nonisolated struct Segment: Hashable, Sendable {
    let surah: Int
    let verse: Int
    /// Words of this ayah on this line, Hafs Unicode text (`text_hafs`). Empty when only the
    /// ayah's end marker wrapped onto this line. VoiceOver and copying use these.
    let words: [String]
    /// The ayah ends on this line: draw its number circle right after the last word.
    let endsAyah: Bool
    /// The same words as V2 glyph codes (`glyph_v2`), drawn only with the page's own font.
    var glyphs: [String] = []
    /// V2 glyph code of the ayah's end marker when `endsAyah` (the page font draws the marker).
    var markerGlyph: String? = nil
    /// Hafs text of the end marker when `endsAyah`: the ayah number in Arabic-Indic digits,
    /// which KFGQPC Hafs draws as one ornamented end-of-ayah glyph.
    var markerText: String? = nil

    var reference: VerseReference { VerseReference(surah: surah, verse: verse) }
}
