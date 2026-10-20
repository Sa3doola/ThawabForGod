//
//  ContinueReadingViews.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// The treatment every Quran widget shares: the theme, the locale carrying the digits, the layout
/// direction, the tap target and the background. The same treatment, in the same order, as
/// `HijriDateWidgetView`. The first three are `quranWidgetTheme`, in `Shared/`.
private struct QuranWidgetChrome: ViewModifier {
    let style: NextPrayerSnapshot.Style
    let link: DeepLink

    func body(content: Content) -> some View {
        content
            .quranWidgetTheme(style: style)
            .widgetURL(link.url)
            .containerBackground(for: .widget) { Theme(accent: style.accent).background }
    }
}

extension View {
    func quranWidgetChrome(style: NextPrayerSnapshot.Style, link: DeepLink) -> some View {
        modifier(QuranWidgetChrome(style: style, link: link))
    }
}

/// The extension's share of Continue Reading: family, tap target, background.
struct ContinueReadingWidgetView: View {

    let entry: QuranWidgetEntry

    @Environment(\.widgetFamily) private var family

    /// A page when there is one; the verse otherwise. Nothing at all falls back to the Quran tab.
    private var link: DeepLink {
        guard let reading = entry.snapshot?.continueReading else { return .quran }
        return reading.page.map(DeepLink.quranPage) ?? .quranVerse(reading.ayah)
    }

    var body: some View {
        QuranContinueReadingContent(entry: entry, family: family.quranFamily)
            .quranWidgetChrome(style: entry.style, link: link)
    }
}
