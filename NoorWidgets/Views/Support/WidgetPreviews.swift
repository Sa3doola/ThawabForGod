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
///
/// Every family of every kind gets one, English above Arabic. Three kinds times three system
/// families is nine layouts, which is nine chances for a string to overflow a slot in one language
/// and not the other.
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

    /// After Isha: the list is tomorrow's, so nothing has passed and nothing is current. The
    /// highlight should land on Fajr rather than nowhere.
    static var afterIsha: NextPrayerSnapshot {
        entry(.schedule(day(current: nil, upcoming: .fajr)))
    }

    // MARK: The date widget

    /// A fixed Hijri date, so the canvas does not change what it is showing between runs.
    static func date(
        _ hijri: HijriDate = HijriDate(day: 10, month: .muharram, year: 1447),
        events: [IslamicEvent] = [],
        style: NextPrayerSnapshot.Style = style()
    ) -> HijriDateSnapshot {
        HijriDateSnapshot(date: Date(), hijri: hijri, events: events, style: style)
    }

    /// A day with something on it, and with the caveat that belongs to it — the layout that has
    /// to survive an event name *and* its note is the one worth looking at.
    static var eventDay: HijriDateSnapshot {
        date(
            HijriDate(day: 1, month: .shawwal, year: 1447),
            events: IslamicEventTable.bundled()
        )
    }

    static var arabicDate: HijriDateSnapshot {
        date(style: style(.arabicIndic, .arabic))
    }
}

// MARK: - Next prayer

#Preview("Next · Small", as: .systemSmall) {
    NextPrayerWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

#Preview("Next · Medium", as: .systemMedium) {
    NextPrayerWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
    WidgetPreviewData.entry(.noLocation)
    WidgetPreviewData.entry(.notComputable)
}

#Preview("Next · Large", as: .systemLarge) {
    NextPrayerWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
    WidgetPreviewData.afterIsha
}

// MARK: - Countdown

#Preview("Countdown · Small", as: .systemSmall) {
    PrayerCountdownWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

#Preview("Countdown · Medium", as: .systemMedium) {
    PrayerCountdownWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

#Preview("Countdown · Large", as: .systemLarge) {
    PrayerCountdownWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

// MARK: - All prayers

#Preview("All · Small", as: .systemSmall) {
    AllPrayersWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

#Preview("All · Medium", as: .systemMedium) {
    AllPrayersWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

#Preview("All · Large", as: .systemLarge) {
    AllPrayersWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
    WidgetPreviewData.afterIsha
}

// MARK: - Hijri date

#Preview("Date · Small", as: .systemSmall) {
    HijriDateWidget()
} timeline: {
    WidgetPreviewData.date()
    WidgetPreviewData.arabicDate
    WidgetPreviewData.eventDay
}

#Preview("Date · Medium", as: .systemMedium) {
    HijriDateWidget()
} timeline: {
    WidgetPreviewData.date()
    WidgetPreviewData.arabicDate
    WidgetPreviewData.eventDay
}

// MARK: - Lock Screen

#if os(iOS)
#Preview("Next · Circular", as: .accessoryCircular) {
    NextPrayerWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

#Preview("Next · Rectangular", as: .accessoryRectangular) {
    NextPrayerWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

#Preview("Next · Inline", as: .accessoryInline) {
    NextPrayerWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

#Preview("Countdown · Circular", as: .accessoryCircular) {
    PrayerCountdownWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

#Preview("Countdown · Rectangular", as: .accessoryRectangular) {
    PrayerCountdownWidget()
} timeline: {
    WidgetPreviewData.schedule
    WidgetPreviewData.arabic
}

/// The one that truncates first — both calendars on a single line, in a language whose month
/// names are longer than English's.
#Preview("Date · Inline", as: .accessoryInline) {
    HijriDateWidget()
} timeline: {
    WidgetPreviewData.date()
    WidgetPreviewData.arabicDate
}

#Preview("Date · Rectangular", as: .accessoryRectangular) {
    HijriDateWidget()
} timeline: {
    WidgetPreviewData.date()
    WidgetPreviewData.arabicDate
    WidgetPreviewData.eventDay
}

#Preview("Date · Circular", as: .accessoryCircular) {
    HijriDateWidget()
} timeline: {
    WidgetPreviewData.date()
    WidgetPreviewData.arabicDate
}
#endif
#endif
