//
//  Theme.swift
//  ThawabForGod
//

import SwiftUI

/// The semantic colour palette a view sees. Nothing in `Features` may reach past these tokens.
nonisolated struct Theme: Equatable, Sendable {
    var primary: Color
    var accent: Color
    var background: Color
    var surface: Color
    var textPrimary: Color
    var textSecondary: Color
    var separator: Color
    var success: Color
    var warning: Color
    var danger: Color

    /// Builds the palette, letting the user's accent choice override the default accent.
    init(accent palette: AccentPalette = .fallback) {
        self.primary = AppColor.primary
        self.accent = AppColor.accent(palette)
        self.background = AppColor.background
        self.surface = AppColor.surface
        self.textPrimary = AppColor.textPrimary
        self.textSecondary = AppColor.textSecondary
        self.separator = AppColor.separator
        self.success = AppColor.success
        self.warning = AppColor.warning
        self.danger = AppColor.danger
    }

    /// The same palette, inverted onto the day ramp.
    ///
    /// The ramp is dark at every hour, so a view drawn on it needs ink that does not follow the
    /// appearance — `TextPrimary` would go black on Fajr's blue-grey the moment the reader chose
    /// light mode. Rather than have each of those views reach past the palette for a fixed
    /// colour, the *palette* is what changes: a card, a widget or a popover head sets this in the
    /// environment once and everything inside it goes on reading the same tokens it always did.
    ///
    /// `success`, `warning` and `danger` deliberately do **not** move. They are fixed across all
    /// four accents precisely so state means one thing everywhere, and the ramp is not an
    /// exception to that — it is a background, not a different app.
    ///
    /// `background` is clear because there is no ground to draw here: the ramp itself is it.
    var onDayRamp: Theme {
        var palette = self
        palette.background = .clear
        palette.surface = DayRamp.Ink.primary.color.opacity(0.14)
        palette.primary = DayRamp.Ink.primary.color
        palette.textPrimary = DayRamp.Ink.primary.color
        palette.textSecondary = DayRamp.Ink.primary.color.opacity(DayRamp.Ink.secondaryOpacity)
        palette.separator = DayRamp.Ink.primary.color.opacity(DayRamp.Ink.railOpacity)
        // The warm cream the lattice and the rail are drawn in, so the one accented thing on the
        // ramp belongs to the ramp rather than to whichever of the four accents is selected.
        palette.accent = DayRamp.Ink.railFill.color
        return palette
    }

    /// The colour a given accent choice would produce.
    ///
    /// For the one screen that has to show all four at once — the swatch picker in Settings —
    /// rather than only the selected one. It lives here so `AppColor` stays the only file that
    /// names an asset colour, and no view has to reach past the palette to draw a preference.
    func color(of palette: AccentPalette) -> Color {
        AppColor.accent(palette)
    }

    /// The page a given paper produces.
    ///
    /// `.system` returns this theme's own colours, which is what makes "follows the app" a real
    /// case rather than a branch every caller repeats. The other papers are fixed, so they carry
    /// the same value in light and dark and the appearance never reaches them.
    func reading(_ paper: ReaderPaper) -> ReadingPalette {
        guard let prefix = paper.assetPrefix else {
            return ReadingPalette(
                background: background,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accent: accent
            )
        }

        return ReadingPalette(
            background: AppColor.paper(prefix),
            textPrimary: AppColor.paper(prefix, .text),
            textSecondary: AppColor.paper(prefix, .secondary),
            accent: AppColor.paper(prefix, .accent)
        )
    }

    static let fallback = Theme()
}
