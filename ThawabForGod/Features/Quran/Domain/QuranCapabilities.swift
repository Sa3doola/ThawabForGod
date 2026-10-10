//
//  QuranCapabilities.swift
//  ThawabForGod
//

import Foundation

/// What the bundled Quran database carries, as its own `meta.capabilities` says (T4).
///
/// Both builds write one schema; a build that lacks something leaves its tables empty and leaves it
/// out of this list, so the app asks one question instead of probing tables. The public (Tanzil)
/// build is `.text` alone, and the screens hide what it cannot do — Mushaf mode and the Library's
/// Page tab (Q5) — by asking `supportsMushafPages`, never by checking which file was bundled.
nonisolated struct QuranCapabilities: OptionSet, Hashable, Sendable {
    let rawValue: Int

    /// `surah`, `ayah`, `ayah_fts`: the text, the divisions and search. Every build has it.
    static let text = QuranCapabilities(rawValue: 1 << 0)
    /// `word`: the word-by-word Hafs text with each ayah's end marker.
    static let words = QuranCapabilities(rawValue: 1 << 1)
    /// `mushaf_line`, `mushaf_page`, `marker`: the printed page.
    static let mushafPages = QuranCapabilities(rawValue: 1 << 2)
    /// `word.glyph_v2`: the page fonts' glyph codes.
    static let glyphV2 = QuranCapabilities(rawValue: 1 << 3)
    /// `font_ligature`: what draws each surah header, surah name and juz name in the QUL faces.
    static let fontLigatures = QuranCapabilities(rawValue: 1 << 4)

    /// The names `meta.capabilities` uses, which are the builder's.
    static let names: [(String, QuranCapabilities)] = [
        ("text", .text), ("words", .words), ("mushafPages", .mushafPages),
        ("glyphV2", .glyphV2), ("fontLigatures", .fontLigatures),
    ]

    /// Parses `meta.capabilities` — `text,words,mushafPages,…`. An unknown name is ignored rather
    /// than failing, so a database from a newer builder still opens on what this build knows.
    init(meta: String) {
        let listed = Set(meta.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        self = QuranCapabilities(Self.names.filter { listed.contains($0.0) }.map(\.1))
    }

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Mushaf mode and the page-numbered views (the Library's Page tab, go to page) are offered.
    var supportsMushafPages: Bool { contains(.mushafPages) }
}
