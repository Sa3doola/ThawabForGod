//
//  FontPackStoring.swift
//  ThawabForGod
//

import Foundation

/// Page fonts (one TTF per Mushaf page, `MushafStyle.pageFonts`) registered on demand from the app
/// bundle. Registering all 604 V2 fonts at launch would be slow and keep them all in memory — the
/// reason `FontRegistrar` skips their folder (T1) — so only a window around the current page is
/// registered.
nonisolated protocol FontPackStoring: Sendable {
    /// Registers the window around `page` (nearest first) and unregisters pages far from it.
    /// Returns once the page itself is registered or known to be unavailable.
    func ensureRegistered(around page: Int, style: MushafStyle) async
    /// Registers one page's font if needed (a page drawn before the pager's window reached it).
    /// Unregisters nothing.
    func ensureRegistered(page: Int, style: MushafStyle) async
    /// Where the page's font stands. Never registers, so it is safe on the main actor.
    func status(page: Int, style: MushafStyleID) -> PageFontStatus
    /// Pages registered right now, for diagnostics and tests.
    func registeredPages(style: MushafStyleID) -> Set<Int>
}

extension FontPackStoring {
    /// The page's font is registered under its PostScript name.
    nonisolated func isRegistered(page: Int, style: MushafStyleID) -> Bool {
        status(page: page, style: style) == .registered
    }
}

nonisolated enum PageFontStatus: Sendable, Equatable {
    /// Registered and resolving to its PostScript name: draw the page with glyphs.
    case registered
    /// Missing or mislabelled: the page uses the Unicode renderer (never retried). Every page, in a
    /// clone without the full data.
    case unavailable
    /// Not registered yet.
    case pending
}

/// Which pages to register around the current one, and which to drop. Pure: the store applies it.
nonisolated struct FontRegistrationWindow: Sendable, Equatable {
    /// Register the current page ± this many pages (a spread and the next page turns).
    let radius: Int
    /// Unregister pages more than this many pages away from the current one.
    let keepDistance: Int

    static let standard = FontRegistrationWindow(radius: 3, keepDistance: 20)

    /// Pages to register, nearest to `page` first (the current page, then the facing and the next
    /// pages), clamped to `pages`.
    func wanted(around page: Int, pages: ClosedRange<Int>) -> [Int] {
        var result: [Int] = []
        for distance in 0...radius {
            for candidate in Set([page + distance, page - distance]).sorted(by: >) where pages.contains(candidate) {
                result.append(candidate)
            }
        }
        return result
    }

    func plan(around page: Int, registered: Set<Int>, pages: ClosedRange<Int>) -> (register: [Int], unregister: [Int]) {
        let register = wanted(around: page, pages: pages).filter { !registered.contains($0) }
        let unregister = registered.filter { abs($0 - page) > keepDistance }.sorted()
        return (register, unregister)
    }
}
