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
