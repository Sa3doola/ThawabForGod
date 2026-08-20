//
//  AppRoute.swift
//  ThawabForGod
//

import Foundation

/// Somewhere in the app a tap can go, named without saying which tab owns it.
///
/// Home is the reason this exists. Its shortcuts and its recent-activity chips open screens that
/// live in three different tabs, and a view that reached for the Quran's coordinator to open a
/// verse would be a feature knowing the shape of the whole app. So a section says *where*, one
/// place at the composition root knows *how* — see `AppContainer.open(_:)` — and everything in
/// between passes a plain `(AppRoute) -> Void`.
///
/// `Hashable` so it can be stored on a value a list diffs, which is what `RecentActivity` needs.
nonisolated enum AppRoute: Hashable, Sendable {
    /// The three screens that are still visits rather than destinations, pushed onto Home's own
    /// stack — see `AppTab` for where that line falls.
    case qibla
    case tasbih
    case names

    case adhkar(AdhkarCategory)

    /// The Quran tab, at its list.
    case quran

    /// The Quran tab, with the chapter this verse belongs to open and scrolled to it.
    case quranVerse(VerseReference)
}
