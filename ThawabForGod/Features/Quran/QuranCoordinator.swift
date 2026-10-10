//
//  QuranCoordinator.swift
//  ThawabForGod
//

import Observation

/// Where the Quran tab is, kept outside the view tree like every other section's.
///
/// **Between engines.** The legacy reader was deleted in M3 of the Mushaf port, and the tab shows
/// `QuranPlaceholderView` until the ported reader arrives (QURAN_MIGRATION_PLAN.md, M5), when this
/// grows the typed `QuranRoute` path and the sheet and panel state Mushaf's router held. What it
/// keeps meanwhile is the one thing a route into the tab carries: the verse that was asked for. So
/// `AppRoute.quranVerse` — a reminder, a recent-activity chip, a widget link — still lands on the
/// Quran tab and still says which verse, and the reader built in M5 has the request waiting.
@Observable
@MainActor
final class QuranCoordinator {

    /// The verse a route asked for, or `nil` at the tab's root.
    private(set) var requestedVerse: VerseReference?

    func open(_ reference: VerseReference) {
        requestedVerse = reference
    }

    func closeReading() {
        requestedVerse = nil
    }
}
