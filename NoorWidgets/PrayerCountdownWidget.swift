//
//  PrayerCountdownWidget.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// How long is left until the next prayer.
///
/// A kind of its own rather than a family of `NextPrayerWidget`, because the two answer different
/// questions and a reader picks between them in the gallery. Everything below the surface is
/// shared: the same `NextPrayerProvider`, over the same `NextPrayerTimeline`, producing the same
/// entries. Only the drawing differs.
///
/// The accessory families are where the split earns itself. The circle is a draining ring and the
/// rectangle a filling bar, both `ProgressView(timerInterval:)`; the next-prayer kind's two
/// carry no progress at all, because nothing about a clock time is elapsing.
struct PrayerCountdownWidget: Widget {

    private let kind = "PrayerCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextPrayerProvider()) { entry in
            PrayerCountdownWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(WidgetGalleryText.string(.widgetCountdownName)))
        .description(Text(WidgetGalleryText.string(.widgetCountdownDescription)))
        .supportedFamilies(Self.supportedFamilies)
    }

    private static var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

struct PrayerCountdownWidgetView: View {

    let entry: NextPrayerSnapshot

    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetChrome(entry: entry) { day in
            switch family {
            case .systemMedium:
                CountdownCompactView(day: day, style: entry.style, timerStyle: .largeTitle)

            case .systemLarge, .systemExtraLarge:
                CountdownLargeView(day: day, style: entry.style)

            #if os(iOS)
            case .accessoryCircular:
                CountdownAccessoryCircularView(day: day, style: entry.style)

            case .accessoryRectangular:
                CountdownAccessoryRectangularView(day: day, style: entry.style)
            #endif

            default:
                CountdownCompactView(day: day, style: entry.style)
            }
        }
    }
}
