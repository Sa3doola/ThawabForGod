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

    /// Where in the open span the reader should be put, or `nil` to start at the top.
    ///
    /// Held here rather than inside `QuranReading` because it is not part of *what* is open: two
    /// bookmarks in Al-Baqara open the same chapter, and folding the verse into the value would
    /// make them two different destinations and push the screen twice. It is also consumed once
    /// — the reader scrolls afterwards, and a target that outlived the scroll would drag them
    /// back to it on the next redraw.
    private(set) var scrollTarget: VerseReference?

    func open(_ reading: QuranReading) {
        openReading = reading
        scrollTarget = nil
    }

    /// Opens the chapter a verse belongs to, positioned at that verse — how a bookmark and
    /// "continue reading" both get back into the text.
    func open(_ reference: VerseReference) {
        openReading = .surah(reference.surah)
        scrollTarget = reference
    }

    /// Called by the reader once it has scrolled. See `scrollTarget`.
    func clearScrollTarget() {
        scrollTarget = nil
    }

    func closeReading() {
        openReading = nil
        scrollTarget = nil
    }

    // MARK: The reading panel

    /// Whether the customization panel is up.
    ///
    /// Here rather than as `@State` on `ReaderView` for the reason `QiblaCoordinator` holds its
    /// manual-location sheet: what is on screen is this type's subject, and a flag on the view
    /// would be the one presentation in the feature that nothing outside the view could reach.
    /// It also survives the reader scrolling, which view state recreated by a redraw need not.
    private(set) var isCustomizing = false

    func customize() {
        isCustomizing = true
    }

    func finishCustomizing() {
        isCustomizing = false
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
