//
//  NextPrayerPreviews.swift
//  NoorWidgets
//

#if DEBUG
import SwiftUI
import WidgetKit

/// Fixed entries for the canvas.
///
/// Widget layout is the one part of this slice a test cannot reach: `NextPrayerTimeline` is
/// covered by `NextPrayerTimelineTests`, but a view only exists inside an extension the test
/// target cannot import. Previews are the substitute — and a better one than adding the widget to
/// a Home Screen each time, because every state can be looked at side by side, including the two
/// that are hard to produce on a real device.
enum WidgetPreviewData {

    /// A day pinned to round hours so the countdown is a readable number rather than astronomy.
    static func day(current: Prayer? = .asr, upcoming: Prayer = .maghrib) -> NextPrayerSnapshot.Day {
        let start = Calendar(identifier: .gregorian).startOfDay(for: Date())

        func at(_ hour: Int, _ minute: Int) -> Date {
            start.addingTimeInterval(TimeInterval(hour * 3_600 + minute * 60))
        }

        let times: [PrayerTime] = [
            PrayerTime(prayer: .fajr, date: at(4, 12)),
            PrayerTime(prayer: .sunrise, date: at(5, 47)),
            PrayerTime(prayer: .dhuhr, date: at(13, 1)),
            PrayerTime(prayer: .asr, date: at(16, 37)),
            PrayerTime(prayer: .maghrib, date: at(19, 33)),
            PrayerTime(prayer: .isha, date: at(20, 53))
        ]

        // Always ahead of the moment the canvas renders, so the timer text has something to run.
        let target = Date().addingTimeInterval(33 * 60 + 40)

        return NextPrayerSnapshot.Day(
            upcoming: UpcomingPrayer(
                time: PrayerTime(prayer: upcoming, date: target),
                isTomorrow: false
            ),
            times: times,
            current: current
        )
    }

    static func style(
        _ system: NumberSystem = .latin,
        _ language: AppLanguage = .english,
        accent: AccentPalette = .fallback
    ) -> NextPrayerSnapshot.Style {
        NextPrayerSnapshot.Style(
            numberSystem: system,
            clockFormat: .system,
            accent: accent,
            language: language
        )
    }

    static func entry(
        _ content: NextPrayerSnapshot.Content,
        style: NextPrayerSnapshot.Style = style()
    ) -> NextPrayerSnapshot {
        NextPrayerSnapshot(date: Date(), content: content, style: style)
    }

    static var schedule: NextPrayerSnapshot { entry(.schedule(day())) }

    /// The same widget an Arabic reader sees: mirrored, Arabic-Indic digits, Arabic labels.
    static var arabic: NextPrayerSnapshot {
        entry(.schedule(day()), style: style(.arabicIndic, .arabic))
    }
}

#Preview("Small", as: .systemSmall) {
    NextPrayerWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

#Preview("Medium", as: .systemMedium) {
    NextPrayerWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
    WidgetPreviewData.entry(.noLocation)
    WidgetPreviewData.entry(.notComputable)
}

#if os(iOS)
#Preview("Lock Screen", as: .accessoryRectangular) {
    NextPrayerWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}
#endif
#endif
