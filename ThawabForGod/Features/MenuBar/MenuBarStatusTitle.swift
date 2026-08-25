//
//  MenuBarStatusTitle.swift
//  ThawabForGod
//

import Foundation

/// What the status item is allowed to draw, and how it gives ground as the menu bar fills up.
///
/// **The rungs are ordered by what may be lost, not by size.** The time is the reason the item
/// exists, so it is the last thing to go and it never narrows: everything above it is dropped
/// first. The name goes before the symbol because the symbol still says *which* prayer — a
/// crescent is Maghrib whether or not the word is beside it — and because a name is the one part
/// whose width depends on the language, so dropping it is also what makes the item behave the
/// same in Arabic as in English.
///
/// The bottom rung is the exception that proves it: at that point there is not room for a
/// countdown either, and an item drawn as half a number would be worse than an item drawn as a
/// symbol. Clicking it still opens the panel, which has the whole day in it.
nonisolated enum MenuBarStatusRung: Equatable, Sendable {
    /// Symbol, name and time. What the item is at any ordinary width.
    case full
    /// The name has gone. The symbol still names the prayer.
    case symbolAndTime
    /// Time alone — the last rung that still counts down.
    case timeOnly
    /// A symbol, and a click that opens the panel.
    case symbolOnly

    var showsSymbol: Bool {
        self != .timeOnly
    }

    var showsName: Bool {
        self == .full
    }

    var showsTime: Bool {
        self != .symbolOnly
    }
}

/// How much of the status item the user wants, before the bar gets a say.
///
/// `automatic` is the default and is the only case that consults the width. The other three pin
/// a rung: somebody who keeps a crowded menu bar and wants Noor to stay small should be able to
/// say so once rather than discover that the item grows back whenever an app quits.
nonisolated enum MenuBarStatusStyle: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case full
    case timeOnly
    case symbolOnly

    var id: String { rawValue }

    /// Which rung this style resolves to at a given amount of free bar.
    ///
    /// `freeWidth` is `nil` when the item has not been placed yet — at the first draw there is no
    /// window to measure — and an unmeasured bar is treated as a roomy one. Guessing small would
    /// mean every launch flickered from a bare symbol to the full title a moment later, which is
    /// the one artefact a status item cannot have: it is on screen at all times and the eye is
    /// drawn to whatever moves.
    func rung(freeWidth: CGFloat?) -> MenuBarStatusRung {
        switch self {
        case .full: return .full
        case .timeOnly: return .timeOnly
        case .symbolOnly: return .symbolOnly
        case .automatic: break
        }

        guard let freeWidth else { return .full }

        if freeWidth >= Threshold.name { return .full }
        if freeWidth >= Threshold.symbol { return .symbolAndTime }
        if freeWidth >= Threshold.time { return .timeOnly }

        return .symbolOnly
    }

    var labelKey: L10nKey {
        switch self {
        case .automatic: .settingsMenuBarStyleAutomatic
        case .full: .settingsMenuBarStyleFull
        case .timeOnly: .settingsMenuBarStyleTimeOnly
        case .symbolOnly: .settingsMenuBarStyleSymbolOnly
        }
    }

    /// The widths at which each part stops fitting, in points of free menu bar.
    ///
    /// From the design, and they are about the *bar* rather than about the item: the item at its
    /// widest is about 96 points, so a bar with 320 points spare is not short of room for it —
    /// it is short of room for everything else, and a status item that crowds out the menus of
    /// the app somebody is actually using has misjudged whose screen it is on.
    enum Threshold {
        /// Below this the name drops.
        static let name: CGFloat = 320
        /// Below this the symbol drops too.
        static let symbol: CGFloat = 200
        /// Below this even the countdown will not fit, and only the symbol is left.
        static let time: CGFloat = 96
    }
}

/// The parts of the title, already resolved and already padded.
///
/// A value rather than a string so the controller can put the pieces where AppKit wants them —
/// the symbol is an `NSImage` on the button, the text is its title — without re-deriving which
/// of them it is supposed to be drawing.
nonisolated struct MenuBarStatusTitle: Equatable, Sendable {
    /// The SF Symbol name, or `nil` at the one rung that has no symbol.
    var symbol: String?

    /// The text of the title: the name, the time, or both. Empty at `symbolOnly`.
    var text: String

    /// What hovering says. Always the whole thing, at every rung — this is where the name goes
    /// when it is dropped, which is what makes dropping it cost nothing.
    var tooltip: String
}

/// The fixed slot the countdown is drawn in.
///
/// **This is the piece that makes the item hold still.** A menu bar label is redrawn once a
/// second in the final hour, and a label whose width follows its contents twitches on every
/// redraw — the name beside it shuffling left and right as `9` gives way to `10`, four times a
/// minute, forever, in the corner of the eye of somebody trying to work.
///
/// So the countdown is padded to the width of the widest string it can ever be and right-aligned
/// inside that, with nothing to its right. Then the only way the label can change width is the
/// single `h:mm` → `mm:ss` transition at the hour boundary, which happens once.
///
/// **Measured, not hard-coded, and measured in characters.** The design's reason for measuring is
/// that Arabic-Indic glyphs run about 18% wider than Western ones, so a slot in points that fits
/// `11:59:59` does not fit `١١:٥٩:٥٩`. Counting characters against a monospaced-digit font
/// sidesteps that entirely: in such a font every digit of a given system has the same advance as
/// every other, so equal character counts *are* equal widths, whichever system is in use. The
/// padding is a FIGURE SPACE, which is defined as exactly the width of a digit.
///
/// The measurement itself goes through the same formatter that renders the countdown, at the
/// interval known to produce its widest output, so the slot cannot drift out of step with the
/// format the way a literal `5` would the moment the format changed.
nonisolated enum MenuBarStatusSlot {

    /// U+2007 FIGURE SPACE — a space as wide as a digit, and non-breaking.
    static let figureSpace = "\u{2007}"

    /// A duration wide enough to render the widest countdown the item can show: two digits of
    /// hours and two of minutes. Any longer gap than this between two prayers is not a case the
    /// schedule produces, and the slot is a *maximum* rather than an exact fit regardless.
    static let widestInterval: TimeInterval = 12 * 3600 + 34 * 60

    /// How many characters the reader actually sees.
    ///
    /// The directional isolates that `briefCountdownString(from:system:)` wraps its result in are
    /// controls: they occupy no width and must not be counted, or the slot would be two
    /// characters too narrow and the padding would do nothing.
    static func visibleLength(of string: String) -> Int {
        // `filter(_:).count` rather than `count(where:)`, which is stdlib 6.0 and so needs
        // iOS 18 — two versions past this app's floor.
        string.unicodeScalars.filter { !isInvisible($0) }.count
    }

    /// Pads a countdown to the slot, on the leading side, so the digits end where they began.
    ///
    /// The padding goes *outside* the isolates rather than inside them. Spaces are directionally
    /// neutral and would take the paragraph's direction, so padding placed inside the isolate
    /// would sit on whichever side the bidi algorithm decided — the right of the digits on an
    /// Arabic system, which is precisely the side the design says nothing may occupy.
    static func padded(_ time: String, toVisibleLength slot: Int) -> String {
        let shortfall = slot - visibleLength(of: time)
        guard shortfall > 0 else { return time }

        return String(repeating: figureSpace, count: shortfall) + time
    }

    private static func isInvisible(_ scalar: UnicodeScalar) -> Bool {
        // The bidi isolate and embedding controls, which is the whole range Foundation would use
        // here — U+2066…U+2069 are the isolates, U+200E/U+200F the marks.
        (0x2066...0x2069).contains(scalar.value)
            || scalar.value == 0x200E
            || scalar.value == 0x200F
    }
}
