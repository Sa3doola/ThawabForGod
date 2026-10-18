//
//  QuranAyahOfTheDayWidget.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// One ayah a day, from the curated list the app publishes ahead of time. Turns over at local
/// midnight without the app being opened. The `kind` string must not change.
struct QuranAyahOfTheDayWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: QuranWidgetKind.ayahOfTheDay, provider: AyahOfTheDayProvider()) { entry in
            AyahOfTheDayWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(WidgetGalleryText.string(.quranWidgetAyahName)))
        .description(Text(WidgetGalleryText.string(.quranWidgetAyahDescription)))
        .supportedFamilies(Self.supportedFamilies)
    }

    private static var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [.systemMedium, .systemLarge, .accessoryRectangular]
        #else
        [.systemMedium, .systemLarge]
        #endif
    }
}

#if DEBUG
#Preview("Quran ayah · Medium", as: .systemMedium) {
    QuranAyahOfTheDayWidget()
} timeline: {
    QuranWidgetPreviewData.entry()
    QuranWidgetPreviewData.entry(QuranWidgetPreviewData.arabic)
    QuranWidgetPreviewData.entry(empty: true)
}

#Preview("Quran ayah · Large", as: .systemLarge) {
    QuranAyahOfTheDayWidget()
} timeline: {
    QuranWidgetPreviewData.entry()
    QuranWidgetPreviewData.entry(QuranWidgetPreviewData.arabic)
}

#if os(iOS)
#Preview("Quran ayah · Rectangular", as: .accessoryRectangular) {
    QuranAyahOfTheDayWidget()
} timeline: {
    QuranWidgetPreviewData.entry()
    QuranWidgetPreviewData.entry(QuranWidgetPreviewData.arabic)
}
#endif
#endif
