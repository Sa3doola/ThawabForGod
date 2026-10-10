//
//  AppColor.swift
//  ThawabForGod
//

import SwiftUI

/// The only place asset-catalog colour names appear. Features use `Theme`, never this type
/// and never a literal colour.
///
/// Every colour set carries both a light and a dark value, so the system resolves the
/// appearance — there is no `if colorScheme == .dark` anywhere in the app.
/// The `Colors/` and `Accents/` asset groups provide a namespace: without it, generated
/// symbols such as `primary` and `separator` collide with SwiftUI's own and the compiler warns.
nonisolated enum AppColor {
    static let primary = Color("Colors/Primary", bundle: .main)
    static let background = Color("Colors/Background", bundle: .main)
    static let surface = Color("Colors/Surface", bundle: .main)
    static let textPrimary = Color("Colors/TextPrimary", bundle: .main)
    static let textSecondary = Color("Colors/TextSecondary", bundle: .main)
    static let separator = Color("Colors/Separator", bundle: .main)
    static let success = Color("Colors/Success", bundle: .main)
    static let warning = Color("Colors/Warning", bundle: .main)
    static let danger = Color("Colors/Danger", bundle: .main)

    static func accent(_ palette: AccentPalette) -> Color {
        Color("Accents/\(palette.assetName)", bundle: .main)
    }

    /// One colour of a Quran reader theme, from the `Reader/<Theme>/` group. Unlike every set
    /// above, these carry a single value for both appearances: a reader theme is a page, and a
    /// page does not change colour when the system does (see `ReaderTheme`).
    static func reader(_ theme: ReaderTheme, _ role: ReaderColorRole) -> Color {
        Color("Reader/\(theme.assetFolder)/\(role.rawValue)", bundle: .main)
    }
}

/// The colours each reader theme names, by their asset names.
nonisolated enum ReaderColorRole: String, CaseIterable, Sendable {
    case background = "Background"
    case text = "Text"
    case secondaryText = "SecondaryText"
    case ornament = "Ornament"
    case selection = "Selection"
    case divider = "Divider"
    case highlightYellow = "HighlightYellow"
    case highlightGreen = "HighlightGreen"
    case highlightBlue = "HighlightBlue"
    case highlightPink = "HighlightPink"
}

private nonisolated extension ReaderTheme {
    var assetFolder: String {
        switch self {
        case .paper: "Paper"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }
}
