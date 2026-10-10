//
//  ReaderFont.swift
//  ThawabForGod
//

import Foundation

/// The face the verses are set in.
///
/// Two, and both licensed for redistribution — which is the whole reason there are only two. The
/// folder these came from held five more Quranic faces; one forbids redistribution, two publish no
/// terms at all, and one of those cannot draw hamzat wasl (ٱ), a letter this corpus uses on
/// almost every line. A face that is on the list is one this project can defend shipping.
///
/// It sits in the design system rather than in the Quran feature because a face is design-system
/// material and the reader is its first caller rather than its owner — the adhkar pin Amiri too.
///
/// **Decoding is by `rawValue` and a stored value that no longer names a case falls back.** A
/// build that shipped other cases (`indoPak`, `naskh`, a face since withdrawn) will have left its
/// raw value in the store, and the answer to a choice that no longer exists is the default, not a
/// crash and not a page drawn in whatever CoreText substitutes for an unknown name.
nonisolated enum ReaderFont: String, CaseIterable, Identifiable, Sendable {

    /// The King Fahd Complex's Hafs face — the Madinah mushaf's own letterforms, and the text the
    /// full (QUL) build is encoded for. The public Tanzil text encodes two marks differently: its
    /// silent-letter circle is U+06DF, which this face draws as a spacing glyph (see
    /// `QuranTextFallback`), and its sukun is U+0652, which this face draws round. The default.
    case kfgqpcHafs

    /// Amiri Quran: a Naskh face with a lighter colour on the page and much taller marks.
    case amiriQuran

    static let fallback: ReaderFont = .kfgqpcHafs

    var id: String { rawValue }

    /// The name CoreText knows the face by — read out of the font files themselves, not guessed
    /// from their file names, which the registrar ignores.
    ///
    /// **`-Regula` is not a typo here; it is the font's.** The KFGQPC file truncates its own
    /// PostScript name to 31 characters, and asking for `-Regular` finds nothing — at which point
    /// CoreText silently substitutes the system face and the page looks almost right.
    /// `FontRegistrarTests` is the only thing that would notice, which is why it exists.
    var postScriptName: String {
        switch self {
        case .kfgqpcHafs: "KFGQPCHAFSUthmanicScript-Regula"
        case .amiriQuran: "AmiriQuran-Regular"
        }
    }

    var labelKey: L10nKey {
        switch self {
        case .kfgqpcHafs: .readerFontKFGQPC
        case .amiriQuran: .readerFontAmiri
        }
    }
}
