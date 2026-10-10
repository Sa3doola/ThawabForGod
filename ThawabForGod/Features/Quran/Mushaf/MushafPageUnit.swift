//
//  MushafPageUnit.swift
//  ThawabForGod
//

import CoreGraphics

/// How the pager shows Mushaf pages at a given size: what one screen of the pager holds.
///
/// Ported from Mushaf. **The size is the reader's own, not the window's** (T11): inside Noor the
/// pager sits in a tab or in the split view's detail column, so an iPad in landscape with the
/// sidebar open is asked about the detail column — and gets a spread only if one fits beside it.
nonisolated enum MushafPageUnit: Hashable, Sendable {
    /// One page fitted to the screen.
    case single
    /// Two facing pages, odd on the right.
    case spread
    /// One page fitted to the width, scrolling vertically within the page (iPhone landscape).
    case widthFit

    /// Pages per pager unit.
    var pageCount: Int { self == .spread ? 2 : 1 }

    /// Width-to-height ratio at which two pages fit side by side (two Madani pages of ratio 0.7
    /// would need 1.4; a little less still reads well).
    static let spreadAspectRatio: CGFloat = 1.2

    /// The rules, in order:
    /// 1. A vertical fold (a foldable iPhone's inner display): a spread, unless the display lies
    ///    flat and the reader prefers one large page.
    /// 2. A compact height (iPhone landscape, Pro Max included): one page fitted to the width, or a
    ///    spread if the reader chose two pages.
    /// 3. A regular width at least 1.2 × the height (iPad landscape, a wide Mac window): a spread.
    /// 4. Otherwise one page fitted to the screen.
    static func resolve(
        size: CGSize,
        fold: FoldKind? = nil,
        isCompactWidth: Bool = false,
        isCompactHeight: Bool = false,
        phoneLandscape: PhoneLandscapeLayout = .onePage,
        flatOpen: FlatOpenLayout = .spread
    ) -> MushafPageUnit {
        switch fold {
        case .book: return .spread
        case .flat: return flatOpen == .spread ? .spread : .single
        case nil: break
        }
        if isCompactHeight {
            return phoneLandscape == .twoPages ? .spread : .widthFit
        }
        if !isCompactWidth, size.width >= size.height * spreadAspectRatio { return .spread }
        return .single
    }

    /// The first page of the unit that shows `page`: odd pages open a spread (1|2, 3|4, …, like the
    /// printed Madinah Mushaf).
    func unitStart(for page: Int) -> Int {
        pageCount == 2 ? page - (page - 1) % 2 : page
    }
}
