//
//  ReaderTheme.swift
//  ThawabForGod
//

import Foundation

/// The page the Quran is read on: Paper, Sepia or Dark (QURAN_MIGRATION_PLAN.md, D4).
///
/// Mushaf's `ReaderTheme`, with its colours moved out of code: each case names a set of colour
/// assets under `Reader/` that `AppColor` reads (T9), so this file says *which* page and the asset
/// catalog says what it looks like.
///
/// **A theme is fixed, not light-and-dark.** Each colour carries one value for both appearances,
/// as Noor's papers did: a reader who chose sepia for the evening did not ask for it to change when
/// the system flips. The one link to the system is the reader's own "use dark when the system is
/// dark" switch, which `resolved(followingSystem:systemIsDark:)` applies.
///
/// It sits in the design system rather than the Quran feature for the reason `ReaderFont` does: a
/// page colour is design-system material, and `Theme.reading(_:)` — the only door to the colours —
/// lives there.
nonisolated enum ReaderTheme: String, CaseIterable, Identifiable, Sendable {
    /// Off-white with black text. The default, and the only theme drawn with the printed surah
    /// header's own colours.
    case paper
    /// Warm cream with brown text.
    case sepia
    /// Near-black with warm grey text.
    case dark

    static let fallback: ReaderTheme = .paper

    var id: String { rawValue }

    var isDark: Bool { self == .dark }

    /// The theme a page is drawn with: the chosen one, or Dark while the system is dark and the
    /// reader asked to follow it. Mushaf's rule, kept: following the system never picks Paper or
    /// Sepia, it only swaps to Dark and back.
    func resolved(followingSystem: Bool, systemIsDark: Bool) -> ReaderTheme {
        followingSystem && systemIsDark ? .dark : self
    }

    var labelKey: L10nKey {
        switch self {
        case .paper: .readerThemePaper
        case .sepia: .readerThemeSepia
        case .dark: .readerThemeDark
        }
    }
}
