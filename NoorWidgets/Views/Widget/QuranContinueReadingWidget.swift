//
//  QuranContinueReadingWidget.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// Where the reader stopped, one tap from the page. The app publishes the position
/// (`QuranWidgetSnapshot`) and reloads this kind by its `kind` string, which must not change.
struct QuranContinueReadingWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: QuranWidgetKind.continueReading, provider: ContinueReadingProvider()) { entry in
            ContinueReadingWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(WidgetGalleryText.string(.quranContinueReading)))
        .description(Text(WidgetGalleryText.string(.quranWidgetContinueDescription)))
        .supportedFamilies(Self.supportedFamilies)
    }

    private static var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .accessoryRectangular]
        #else
        [.systemSmall, .systemMedium]
        #endif
    }
}

#if DEBUG
/// References and placeholder strings only: no Quran text appears in code, even in a preview.
enum QuranWidgetPreviewData {
    static func entry(
        _ style: NextPrayerSnapshot.Style = WidgetPreviewData.style(),
        empty: Bool = false,
        page: Int? = 50
    ) -> QuranWidgetEntry {
        guard !empty else { return QuranWidgetEntry(date: Date(), snapshot: nil, style: style, hasHafs: false) }
        var snapshot = QuranWidgetSnapshot()
        snapshot.continueReading = .init(
            ayah: VerseReference(surah: 18, verse: 40),
            surahNameArabic: "الكهف",
            surahNameEnglish: "Al-Kahf",
            page: page,
            juz: page == nil ? nil : 15
        )
        let key = DailyAyahRule.dayKey(for: Date(), calendar: DailyAyahRule.calendar)
        snapshot.days = [
            .init(
                day: key, first: VerseReference(surah: 2, verse: 255), lastVerse: 256,
                surahNameArabic: "البقرة", surahNameEnglish: "Al-Baqarah",
                texts: ["…", "…"], translation: nil
            )
        ]
        return QuranWidgetEntry(date: Date(), snapshot: snapshot, style: style, hasHafs: false)
    }

    static var arabic: NextPrayerSnapshot.Style { WidgetPreviewData.style(.arabicIndic, .arabic) }
}

#Preview("Quran continue · Small", as: .systemSmall) {
    QuranContinueReadingWidget()
} timeline: {
    QuranWidgetPreviewData.entry()
    QuranWidgetPreviewData.entry(QuranWidgetPreviewData.arabic)
    QuranWidgetPreviewData.entry(empty: true)
}

#Preview("Quran continue · Medium", as: .systemMedium) {
    QuranContinueReadingWidget()
} timeline: {
    QuranWidgetPreviewData.entry()
    QuranWidgetPreviewData.entry(QuranWidgetPreviewData.arabic)
    QuranWidgetPreviewData.entry(page: nil)
}

#if os(iOS)
#Preview("Quran continue · Rectangular", as: .accessoryRectangular) {
    QuranContinueReadingWidget()
} timeline: {
    QuranWidgetPreviewData.entry()
    QuranWidgetPreviewData.entry(QuranWidgetPreviewData.arabic)
}
#endif
#endif
