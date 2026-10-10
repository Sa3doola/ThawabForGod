//
//  QuranReaderPreferences.swift
//  ThawabForGod
//

import Foundation

// The reader's layout choices, ported from Mushaf's `ReaderSettings` (QURAN_MIGRATION_PLAN.md,
// D4). Each is its own `SettingsKey` holding a raw value, so the raw values are stored strings:
// rename a case and keep its raw value. A stored value that names no case falls back to the
// default, as `ReaderFont` does.

/// How the Quran is shown: the printed page, or one ayah after another.
nonisolated enum QuranDisplayMode: String, CaseIterable, Identifiable, Sendable {
    /// One row per ayah, at the reader's own text size. Every build has it.
    case separated
    /// The printed Madani page, fitted to the screen. Only a build with the printed layout
    /// (`QuranCapabilities.supportsMushafPages`) offers it.
    case mushaf

    var id: String { rawValue }

    var labelKey: L10nKey {
        switch self {
        case .separated: .readerModeSeparated
        case .mushaf: .readerModeMushaf
        }
    }
}

/// Mushaf pages on an iPhone held in landscape: one page fitted to the width (scrolled down), or a
/// two-page spread.
nonisolated enum PhoneLandscapeLayout: String, CaseIterable, Identifiable, Sendable {
    case onePage, twoPages

    static let fallback: PhoneLandscapeLayout = .onePage

    var id: String { rawValue }

    var labelKey: L10nKey {
        switch self {
        case .onePage: .readerLandscapeOnePage
        case .twoPages: .readerLandscapeTwoPages
        }
    }
}

/// Mushaf pages on a foldable iPhone opened flat: a spread across the fold, or one large page.
nonisolated enum FlatOpenLayout: String, CaseIterable, Identifiable, Sendable {
    case spread, singlePage

    static let fallback: FlatOpenLayout = .spread

    var id: String { rawValue }

    var labelKey: L10nKey {
        switch self {
        case .spread: .readerFlatOpenSpread
        case .singlePage: .readerFlatOpenSinglePage
        }
    }
}
