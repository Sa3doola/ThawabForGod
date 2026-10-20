//
//  MushafPagerStep.swift
//  ThawabForGod
//

/// A page turn, in reading order: `next` is the page after this one, which in a Mushaf lies to the
/// left.
nonisolated enum MushafPageTurn: Equatable, Sendable {
    case next, previous
}

/// The pager's page-step maths and its rule for telling a real scroll report from a stray one.
/// Pure: no view, no state, so the edges are unit-tested.
nonisolated enum MushafPagerStep {
    /// First page of the unit `turn` leads to; nil past either end. Spreads step from the odd page.
    static func target(of turn: MushafPageTurn, from page: Int, pageCount: Int, pages: ClosedRange<Int>) -> Int? {
        let start = unitStart(of: page, pageCount: pageCount)
        switch turn {
        case .next:
            let next = start + pageCount
            return next <= pages.upperBound ? next : nil
        case .previous:
            return start > pages.lowerBound ? max(start - pageCount, pages.lowerBound) : nil
        }
    }

    /// A report from the scroll view is honoured if it is the pending jump target, or (no jump pending)
    /// within one unit of the current unit. Anything else is stray (the mirrored RTL origin).
    static func accepts(reported: Int, page: Int, pageCount: Int, jumpTarget: Int?) -> Bool {
        if let jumpTarget { return reported == jumpTarget }
        return abs(reported - unitStart(of: page, pageCount: pageCount)) <= pageCount
    }

    /// The odd page of a spread, else the page itself.
    private static func unitStart(of page: Int, pageCount: Int) -> Int {
        pageCount == 2 ? page - (page - 1) % 2 : page
    }
}
