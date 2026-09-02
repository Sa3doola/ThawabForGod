//
//  AllPrayersWidget.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// The five obligatory prayers of the day, with the current one picked out.
///
/// **No accessory families.** Five rows do not go into a Lock Screen slot, and the honest small
/// version of this widget — one row — is already the next-prayer kind. A gallery entry that could
/// only ever be a worse copy of another one is not worth the row it takes up.
struct AllPrayersWidget: Widget {

    private let kind = "AllPrayersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextPrayerProvider()) { entry in
            AllPrayersWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(WidgetGalleryText.string(.widgetAllPrayersName)))
        .description(Text(WidgetGalleryText.string(.widgetAllPrayersDescription)))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AllPrayersWidgetView: View {

    let entry: NextPrayerSnapshot

    var body: some View {
        WidgetChrome(entry: entry) { day in
            AllPrayersView(day: day, style: entry.style)
        }
    }
}
