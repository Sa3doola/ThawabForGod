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
/// It sits beside `ReaderPaper` rather than in the Quran feature for the reason that type gives: a
/// face is design-system material, and the reader is its first caller rather than its owner.
///
/// **Decoding is by `rawValue` and a stored value that no longer names a case falls back.** A
/// build that shipped other cases (`indoPak`, `naskh`, a face since withdrawn) will have left its
/// raw value in the store, and the answer to a choice that no longer exists is the default, not a
/// crash and not a page drawn in whatever CoreText substitutes for an unknown name.
nonisolated enum ReaderFont: String, CaseIterable, Identifiable, Sendable {

    /// The King Fahd Complex's Hafs face — the Madinah mushaf's own letterforms, and the text this
    /// corpus is encoded for. The default.
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

// TODO(license): confirm redistribution rights before App Store release. "ayat quran" is listed
// as Freeware on fontspace.com, which is a download page and not a licence — nothing published
// says the files may be bundled in an app.

/// The ornament an ayah's number is drawn inside — twelve designs of the same circle.
///
/// Each is a separate font whose ligatures turn a typed number, 1 through 286, into a finished
/// medallion. That range is not arbitrary: Al-Baqara has 286 verses, so it is every number the
/// mushaf needs and no more.
nonisolated enum AyahMarkerStyle: Int, CaseIterable, Identifiable, Sendable {
    case style1 = 1
    case style2
    case style3
    case style4
    case style5
    case style6
    case style7
    case style8
    case style9
    case style10
    case style11
    case style12

    static let fallback: AyahMarkerStyle = .style1

    var id: Int { rawValue }

    /// The names CoreText registers the files under. The inconsistency — `ayatquran1` but
    /// `ayat-quran-2` — is the fonts' own: nine of the twelve files carry a PostScript name with
    /// spaces in it, which PostScript does not allow, and CoreText registers those with each space
    /// turned into a hyphen. The spaced form still *finds* the face, but it is not the name the
    /// face reports back, so the canonical spelling is the one written here and the one
    /// `FontRegistrarTests` can hold it to.
    var postScriptName: String {
        switch self {
        case .style1: "ayatquran1"
        case .style5: "ayatquran5"
        case .style9: "ayatquran9"
        default: "ayat-quran-\(rawValue)"
        }
    }
}
