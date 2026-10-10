//
//  ReadingPalette.swift
//  ThawabForGod
//

import SwiftUI

/// The colours a Quran page is drawn in: one `ReaderTheme`, resolved.
///
/// Mushaf's `ReaderPalette`, with its literals moved into the asset catalog (T9): the values live
/// in `Reader/<Theme>/` colour sets, `AppColor` is the only file that names them, and a view
/// reaches them through `Theme.reading(_:)` or `\.readingPalette` — never a `Color(red:…)`.
///
/// Every text colour here meets WCAG AA on its page, and on the selection and each highlight
/// drawn behind it; `ReaderContrastTests` holds that, theme by theme.
nonisolated struct ReadingPalette: Equatable, Sendable {
    let theme: ReaderTheme
    let background: Color
    /// The Quran text, translations and the basmala.
    let text: Color
    /// Page chrome: the surah name, juz and page number.
    let secondaryText: Color
    /// Margin labels (juz, hizb, quarter, sajdah), the tinted surah-header frame, the bookmark
    /// ribbon.
    let ornament: Color
    /// The band behind a selected ayah. Translucent: the text is drawn over it.
    let selection: Color
    let divider: Color

    init(theme: ReaderTheme) {
        self.theme = theme
        background = AppColor.reader(theme, .background)
        text = AppColor.reader(theme, .text)
        secondaryText = AppColor.reader(theme, .secondaryText)
        ornament = AppColor.reader(theme, .ornament)
        selection = AppColor.reader(theme, .selection)
        divider = AppColor.reader(theme, .divider)
    }

    /// The band behind an ayah the reader highlighted, in this theme's shade of `color`.
    /// Translucent, like the selection.
    func highlight(_ color: HighlightColor) -> Color {
        switch color {
        case .yellow: AppColor.reader(theme, .highlightYellow)
        case .green: AppColor.reader(theme, .highlightGreen)
        case .blue: AppColor.reader(theme, .highlightBlue)
        case .pink: AppColor.reader(theme, .highlightPink)
        }
    }

    /// Surah headers in the printed Mushaf's own colours (the COLR header font, whose colours no
    /// foreground style changes). Paper only: on a tinted or dark page the print's red and gold
    /// fight the ground, so the other themes draw the frame in `ornament` and the name in `text`.
    var usesPrintHeader: Bool { theme == .paper }

    /// Light or dark for the system controls drawn over the page — a context menu, a scroll
    /// indicator — so they match the page rather than the app.
    var colorScheme: ColorScheme { theme.isDark ? .dark : .light }

    /// What a view outside the reader gets: Paper, the default theme.
    static let fallback = ReadingPalette(theme: .fallback)
}

extension Theme {
    /// The page colours for a reader theme. Here rather than as a stored property because a page's
    /// colours depend on the reader's choice, not the app's accent, and the reader is the only
    /// screen that asks.
    func reading(_ theme: ReaderTheme) -> ReadingPalette {
        ReadingPalette(theme: theme)
    }
}
