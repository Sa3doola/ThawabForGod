//
//  MushafReadingState.swift
//  ThawabForGod
//

import Observation

/// Where the Mushaf pager is and what is selected on it — the part of Mushaf's `ReaderModel` the
/// renderer needs.
///
/// Separate from the reader's view model on purpose: the pager, its units and every page observe
/// this, and a change here (a page turn, a selection) should redraw them and nothing else. The
/// reader's view model (`QuranReaderViewModel`) owns one for the session and does the navigation.
@Observable
@MainActor
final class MushafReadingState {
    /// The page the reader is on. In a spread, either of the two.
    private(set) var page: Int
    var selectedAyah: VerseReference?
    /// Pages the pager shows at once (1, or 2 for a spread), reported by the pager.
    var visiblePageCount = 1
    /// iPhone immersive reading: the reader's bars are hidden.
    var isChromeHidden = false

    let pages: ClosedRange<Int>

    init(page: Int = 1, pages: ClosedRange<Int>) {
        self.pages = pages
        self.page = min(max(page, pages.lowerBound), pages.upperBound)
    }

    /// Moves to `page`, clamped to the style's pages.
    func show(page: Int) {
        let clamped = min(max(page, pages.lowerBound), pages.upperBound)
        if clamped != self.page { self.page = clamped }
    }

    /// The first page of the unit on screen: the odd page of a spread, else the page itself.
    private var unitStart: Int {
        visiblePageCount == 2 ? page - (page - 1) % 2 : page
    }

    /// One unit forward or back: a page, or a spread when two are showing.
    func turn(_ turn: MushafPageTurn) {
        switch turn {
        case .next: show(page: unitStart + visiblePageCount)
        case .previous: show(page: unitStart - visiblePageCount)
        }
    }

    func canTurn(_ turn: MushafPageTurn) -> Bool {
        switch turn {
        case .next: unitStart + visiblePageCount <= pages.upperBound
        case .previous: unitStart > pages.lowerBound
        }
    }

    func select(_ ayah: VerseReference?) {
        selectedAyah = ayah
    }
}
