//
//  MushafTapZones.swift
//  ThawabForGod
//

import SwiftUI

/// A page turn, in reading order: `next` is the page after this one, which in a Mushaf lies to the
/// left.
nonisolated enum MushafPageTurn: Equatable, Sendable {
    case next, previous
}

/// Immersive reading on iPhone: where a tap on a Mushaf page lands. The outer 15% on each side
/// turns the page (the left edge is the next page: a Mushaf is an Arabic book); elsewhere a tap
/// selects its ayah or, outside the text, shows or hides the reader's chrome. Ported from Mushaf.
nonisolated enum MushafTapZone: Equatable, Sendable {
    case nextPage, previousPage, middle

    /// Share of the width on each side that turns the page.
    static let edgeFraction: CGFloat = 0.15

    /// `x` from the left edge of a page unit `width` wide (screen geometry, never mirrored).
    static func zone(x: CGFloat, width: CGFloat) -> MushafTapZone {
        guard width > 0 else { return .middle }
        if x < width * edgeFraction { return .nextPage }
        if x > width * (1 - edgeFraction) { return .previousPage }
        return .middle
    }
}

/// What a tap on a page does, handed down by the pager while immersive reading is on (iPhone,
/// VoiceOver off). `nil` elsewhere: taps select ayahs and nothing else.
struct MushafTapHandling {
    /// The coordinate space the taps are measured in: the page unit.
    static let space = "mushafUnit"

    /// Width of the page unit (the whole screen width).
    let width: CGFloat
    let turn: (MushafPageTurn) -> Void
    let toggleChrome: () -> Void

    /// For a tap on an ayah's words: turns the page and returns `true` in an edge zone.
    func turnsPage(at location: CGPoint) -> Bool {
        switch MushafTapZone.zone(x: location.x, width: width) {
        case .nextPage: turn(.next)
        case .previousPage: turn(.previous)
        case .middle: return false
        }
        return true
    }

    /// For a tap outside the text: the edges turn the page, the middle shows or hides the chrome.
    func tapOutsideText(at location: CGPoint) {
        if !turnsPage(at: location) { toggleChrome() }
    }
}

extension EnvironmentValues {
    @Entry var mushafTapHandling: MushafTapHandling?
}
