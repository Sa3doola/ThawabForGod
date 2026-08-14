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

    static let fallback = Theme()
}
