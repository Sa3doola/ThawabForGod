//
//  AppMetrics.swift
//  ThawabForGod
//

import Foundation

/// The spacing scale. Eight steps, and a view may use no number that is not one of them.
///
/// A closed set for the same reason the colours are one: a screen built from `12` and `16` reads
/// as the same system as the screen beside it, and a screen built from `13` and `15` does not.
/// The names are the numbers because the numbers are the vocabulary the design speaks — `.md`
/// would be a second name for a thing that already has one, and it hides which of two adjacent
/// steps a view actually took.
nonisolated enum AppSpacing {
    /// Hairline separation — a kicker from the line it labels.
    static let xxs: CGFloat = 2
    /// Inside a label: a symbol from its word.
    static let xs: CGFloat = 4
    /// Between the lines of one idea.
    static let sm: CGFloat = 8
    /// Between the parts of a card.
    static let md: CGFloat = 12
    /// A card's own padding, and the gap between two cards.
    static let lg: CGFloat = 16
    /// A screen's outer margin.
    static let xl: CGFloat = 24
    /// Between two groups of cards.
    static let xxl: CGFloat = 32
    /// The gap that says a section has ended.
    static let xxxl: CGFloat = 48

    /// A list row's own padding — the one step that is not the same on every platform.
    ///
    /// The design puts Mac rows at 32 points where touch rows are 44, and the reason is the
    /// instrument rather than the taste: a fingertip needs a target it can hit without looking,
    /// and a cursor is a single pixel. Holding the Mac to the phone's number is how a settings
    /// window ends up three screens long and a chapter list shows nine of a hundred and fourteen.
    ///
    /// It is still a step of the scale, not a bespoke number — `md` rather than `10` — so a Mac
    /// row lines up with everything around it. See `AppBreakpoint.minimumTapTarget`, which is the
    /// same argument about the target rather than the padding.
    #if os(macOS)
    static let row: CGFloat = md
    #else
    static let row: CGFloat = lg
    #endif
}

/// The corner radii. Four steps, and the last is a pill rather than a number.
///
/// Anything round in this app is round by one of these. `pill` is deliberately an absurd number
/// rather than "half the height": a view that has to measure itself to know its own radius is a
/// view that cannot be composed, and `.rect(cornerRadius:)` clamps to half anyway.
nonisolated enum AppRadius {
    /// Chips, verse markers, the small tiles inside a card.
    static let sm: CGFloat = 6
    /// Controls and inner surfaces.
    static let md: CGFloat = 12
    /// Cards — the default for anything the eye reads as a surface.
    static let lg: CGFloat = 18
    /// Buttons, badges, the shortcut circles.
    static let pill: CGFloat = 999
}
