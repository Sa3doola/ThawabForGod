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

    /// One tone of a reading paper.
    ///
    /// A suffix rather than four named constants per paper, because the sets are named as a
    /// family — `PaperParchment`, `PaperParchmentText` — and a `switch` over eight cases would
    /// only be that same string joined by hand. The prefix comes from `ReaderPaper`, which is
    /// the type entitled to know a paper has assets at all.
    enum PaperTone: String {
        case background = ""
        case text = "Text"
        case secondary = "Secondary"
        case accent = "Accent"
    }

    static func paper(_ prefix: String, _ tone: PaperTone = .background) -> Color {
        Color("Papers/\(prefix)\(tone.rawValue)", bundle: .main)
    }
}
