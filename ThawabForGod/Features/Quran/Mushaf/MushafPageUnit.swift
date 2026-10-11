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
    /// 3. A regular width at least 1.2 × the height (iPad landscape, a wide Mac window): a spread,
    ///    unless `spreadFit` says the text would be set below its floor, when it is one page.
    /// 4. Otherwise one page fitted to the screen.
    ///
    /// Rules 1 and 2 are the reader's own choices (a fold, a landscape preference) and ignore the floor.
    static func resolve(
        size: CGSize,
        fold: FoldKind? = nil,
        isCompactWidth: Bool = false,
        isCompactHeight: Bool = false,
        phoneLandscape: PhoneLandscapeLayout = .onePage,
        flatOpen: FlatOpenLayout = .spread,
        spreadFit: MushafSpreadFit? = nil
    ) -> MushafPageUnit {
        switch fold {
        case .book: return .spread
        case .flat: return flatOpen == .spread ? .spread : .single
        case nil: break
        }
        if isCompactHeight {
            return phoneLandscape == .twoPages ? .spread : .widthFit
        }
        if !isCompactWidth, size.width >= size.height * spreadAspectRatio {
            if let spreadFit, spreadFit.estimatedFontSize(in: size) < MushafSpreadFit.minimumFontSize { return .single }
            return .spread
        }
        return .single
    }

    /// The first page of the unit that shows `page`: odd pages open a spread (1|2, 3|4, …, like the
    /// printed Madinah Mushaf).
    func unitStart(for page: Int) -> Int {
        pageCount == 2 ? page - (page - 1) % 2 : page
    }
}

/// What it takes to estimate the text size a spread would give, so rule 3 can fall back to one page
/// when two would set the words too small to read. Pure arithmetic over the style's numbers.
nonisolated struct MushafSpreadFit: Hashable, Sendable {
    let pageAspectRatio: CGFloat
    let linesPerPage: Int
    /// The renderer's line-slot height in ems. Pass the larger renderer's, so the estimate leans
    /// towards one page rather than towards unreadable text.
    let slotHeightEm: CGFloat

    /// Below this a spread gives way to one page.
    static let minimumFontSize: CGFloat = 18

    /// Font size in points for two pages in `size`: each page is as tall as the height allows or as
    /// the half-width allows, whichever is less.
    func estimatedFontSize(in size: CGSize) -> CGFloat {
        guard pageAspectRatio > 0, linesPerPage > 0, slotHeightEm > 0 else { return 0 }
        let pageHeight = min(size.height, size.width / 2 / pageAspectRatio)
        return pageHeight / CGFloat(linesPerPage) / slotHeightEm
    }
}
