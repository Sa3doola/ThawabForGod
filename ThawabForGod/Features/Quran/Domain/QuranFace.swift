//
//  QuranFace.swift
//  ThawabForGod
//

import Foundation

/// The bundled faces the Mushaf draws with, named as data rather than as fonts.
///
/// Mushaf's `QuranFont`, split the way this project splits things: the names live here, in Domain,
/// because `MushafStyle` says which face draws its headers and names; turning one into a `Font`,
/// and knowing which of them registered, is the renderer's (M4), alongside `ReaderFont`.
///
/// Only `ayahText` is bundled in every clone. The three QUL faces are installed by
/// `Tools/QuranBuilder --profile qul` and git-ignored, so a public build draws without them.
nonisolated enum QuranFace: CaseIterable, Hashable, Sendable {
    /// KFGQPC Hafs Uthmanic Script: ayah text. The same file as `ReaderFont.kfgqpcHafs`.
    case ayahText
    /// QUL `surah-header.ttf`: one colour glyph per surah draws the whole Mushaf header line
    /// (frame and name) in the print's own colours. Code points come from `Surah.headerGlyph`.
    case surahHeader
    /// QUL `surah-name-v2.ttf`: the ligature "surah001"…"surah114" (`Surah.nameGlyph`) draws the
    /// calligraphic name with "سورة". Lists, titles and separated mode.
    case surahName
    /// QUL `quran-common.ttf`: juz names ("j001"…), makkah/madinah icons.
    case quranCommon

    /// Exact PostScript names as stored in the font files — CoreText substitutes silently for a
    /// name it does not know, so these are checked against the files (`FontRegistrarTests`).
    var postScriptName: String {
        switch self {
        case .ayahText: "KFGQPCHAFSUthmanicScript-Regula" // the missing "r" is in the font itself
        case .surahHeader: "QCF_SurahHeader_COLOR"
        case .surahName: "surah-name-v2"
        case .quranCommon: "quran-common"
        }
    }

    /// File name in the app bundle, without extension.
    var resourceName: String {
        switch self {
        case .ayahText: "KFGQPC-HafsUthmanic"
        case .surahHeader: "surah-header"
        case .surahName: "surah-name-v2"
        case .quranCommon: "quran-common"
        }
    }
}
