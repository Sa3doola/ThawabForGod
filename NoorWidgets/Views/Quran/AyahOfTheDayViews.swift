//
//  AyahOfTheDayViews.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// The extension's share of the Ayah of the Day: which family is on screen, where a tap goes, and
/// the background. Everything drawn is `QuranAyahOfTheDayContent`, in `Shared/`, so a test can render it.
struct AyahOfTheDayWidgetView: View {

    let entry: QuranWidgetEntry

    @Environment(\.widgetFamily) private var family

    private var link: DeepLink {
        entry.snapshot?.dailyAyah(for: entry.date).map { .quranVerse($0.first) } ?? .quran
    }

    var body: some View {
        QuranAyahOfTheDayContent(entry: entry, family: family.quranFamily)
            .quranWidgetChrome(style: entry.style, link: link)
    }
}

extension WidgetFamily {
    /// The families the two Quran widgets declare, in the vocabulary `Shared/` draws with.
    var quranFamily: QuranWidgetFamily {
        switch self {
        case .systemSmall: .small
        case .systemLarge, .systemExtraLarge: .large
        #if os(iOS)
        case .accessoryRectangular: .rectangular
        #endif
        default: .medium
        }
    }
}
