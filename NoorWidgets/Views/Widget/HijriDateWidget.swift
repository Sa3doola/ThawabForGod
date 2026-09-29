//
//  HijriDateWidget.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// Today, in both calendars.
///
/// A kind of its own rather than another family of a prayer widget, and the accessory slot is the
/// reason: a widget declares **one** `accessoryInline` view, and the next-prayer kind has already
/// spent its on "Maghrib 6:15 PM". A reader who wants the date above their clock and the next
/// prayer somewhere else needs two entries in the gallery to put there.
///
/// It is also the one widget in this bundle that can always answer. The others need a position and
/// say so when they have none; a date needs nothing but a time zone, so there is no `noLocation`
/// state anywhere below this.
struct HijriDateWidget: Widget {

    private let kind = "HijriDateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HijriDateProvider()) { entry in
            HijriDateWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(WidgetGalleryText.string(.widgetHijriDateName)))
        .description(Text(WidgetGalleryText.string(.widgetHijriDateDescription)))
        .supportedFamilies(Self.supportedFamilies)
    }

    private static var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ]
        #else
        [.systemSmall, .systemMedium]
        #endif
    }
}

/// Picks the layout for the family.
///
/// It does not use `WidgetChrome`: that wrapper switches over `NextPrayerSnapshot.Content` and its
/// three states, and this entry has one state. What it shares instead is the *treatment* — the
/// theme, the locale carrying the digits, the layout direction — which `dateChrome` applies here
/// in the same order and with the same reasons.
struct HijriDateWidgetView: View {

    let entry: HijriDateSnapshot

    @Environment(\.widgetFamily) private var family

    private var theme: Theme { Theme(accent: entry.style.accent) }
    private var l10n: WidgetLocalization { WidgetLocalization(entry.style) }

    var body: some View {
        content
            .environment(\.theme, isSystemFamily ? theme.onDayRamp : theme)
            .environment(\.locale, l10n.locale)
            .environment(
                \.layoutDirection,
                entry.style.language.isRightToLeft ? .rightToLeft : .leftToRight
            )
            .widgetURL(DeepLink.home.url)
            .containerBackground(for: .widget) {
                if isSystemFamily {
                    // The day's light, taken at the *hour the entry begins* rather than from a
                    // prayer — this widget knows nothing about prayers. Fajr's stop is the one
                    // that reads as daybreak, which is what a date turning over at midnight is.
                    DayRampBackground(stop: DayRamp.stop(for: .fajr))
                } else {
                    theme.background
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            HijriDateAccessoryCircularView(entry: entry)

        case .accessoryRectangular:
            HijriDateAccessoryRectangularView(entry: entry)

        case .accessoryInline:
            HijriDateAccessoryInlineView(entry: entry)
        #endif

        default:
            HijriDateSystemView(entry: entry)
        }
    }

    private var isSystemFamily: Bool {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge: true
        default: false
        }
    }
}
