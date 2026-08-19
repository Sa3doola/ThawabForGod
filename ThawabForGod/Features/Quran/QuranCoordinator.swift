//
//  QuranCoordinator.swift
//  ThawabForGod
//

import Observation

/// Owns what the reader has open, and nothing else.
///
/// No `NavigationPath` here, for the reason `AdhkarCoordinator` has none: the Quran tab's own
/// `NavigationStack` is put up once by `MainTabView`, and a second path would mean a stack
/// nested inside that one. What this holds is the one value that decides whether the reading
/// screen is on top, driven through `navigationDestination(item:)` so a push and a back swipe
/// are the same value changing.
@Observable
@MainActor
final class QuranCoordinator {

    /// What is being read, or `nil` at the list.
    private(set) var openReading: QuranReading?

    func open(_ reading: QuranReading) {
        openReading = reading
    }

    func closeReading() {
        openReading = nil
    }
}

/// The two ways into the text, which are the two lists the tab offers.
///
/// A chapter and a part are the same screen with a different span of verses on it, so they are
/// one type rather than two destinations — the reader does not change shape depending on which
/// list the reader came from.
nonisolated enum QuranReading: Hashable, Sendable, Identifiable {
    case surah(Int)
    case juz(Int)

    var id: Self { self }
}
