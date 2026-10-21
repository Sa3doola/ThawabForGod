//
//  MushafCurlOrder.swift
//  ThawabForGod
//

/// Which Mushaf page lies on which side of another in a page-curl book — the one place the Arabic
/// book's direction is decided, so a device that shows it backwards is a one-line fix here.
///
/// `UIPageViewController` thinks in its own order: "after" a controller is the one to its right
/// (or the next sheet), "before" the one to its left. A Mushaf reads right to left, so reading order
/// and UIKit order agree or disagree depending on the spine:
///
/// - **Single page, spine on the right edge (`.max`).** The page lifts from the left edge and turns
///   over to the right. UIKit "after" is the reading-next page, and `.forward` means next.
/// - **Spread, spine in the middle (`.mid`).** The odd page is on the right and the even one on the
///   left, so UIKit's left-to-right order is the *reverse* of reading order: "after" is the page
///   before in reading (page − 1), "before" is the one after (page + 1), and `.reverse` means next.
///
/// Pure, so it holds without a view controller.
nonisolated enum MushafCurlOrder {
    /// How the curl is laid out.
    enum Spine: Equatable, Sendable {
        /// One page, spine on the right edge.
        case single
        /// Two facing pages, spine between them.
        case spread

        init(unit: MushafPageUnit) {
            self = unit == .spread ? .spread : .single
        }
    }

    /// Direction of a programmatic turn, as `UIPageViewController.NavigationDirection` names it.
    enum Direction: Equatable, Sendable {
        case forward, reverse
    }

    /// The pages of the unit starting at `first`, in the order UIKit wants its controllers (left to
    /// right on screen). A spread is exactly two: `[first + 1, first]`, even page left, odd right.
    static func pages(inUnitStarting first: Int, spine: Spine) -> [Int] {
        switch spine {
        case .single: [first]
        case .spread: [first + 1, first]
        }
    }

    /// The page UIKit shows *after* `page`; nil past either end of `pages`.
    static func pageAfter(_ page: Int, spine: Spine, pages: ClosedRange<Int>) -> Int? {
        let candidate = spine == .single ? page + 1 : page - 1
        return pages.contains(candidate) ? candidate : nil
    }

    /// The page UIKit shows *before* `page`; nil past either end of `pages`.
    static func pageBefore(_ page: Int, spine: Spine, pages: ClosedRange<Int>) -> Int? {
        let candidate = spine == .single ? page - 1 : page + 1
        return pages.contains(candidate) ? candidate : nil
    }

    /// The direction to pass to `setViewControllers` when moving from the unit at `from` to the one
    /// at `to`, both in reading terms (a larger page is later in the book).
    static func direction(from: Int, to: Int, spine: Spine) -> Direction {
        let isNext = to > from
        switch spine {
        case .single: return isNext ? .forward : .reverse
        case .spread: return isNext ? .reverse : .forward
        }
    }

    /// First page of the unit that the visible `pages` make up (the odd page of a spread); nil for none.
    static func unitStart(ofVisible pages: [Int]) -> Int? {
        pages.min()
    }
}
