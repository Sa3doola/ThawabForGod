//
//  NextPrayerWidget.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// The next prayer, and how long is left.
///
/// `StaticConfiguration`, not `AppIntentConfiguration`. A configurable widget would need the
/// AppIntents framework in both targets and an intent type whose schema outlives every release
/// that ships it — a slice of its own, and one with nothing to configure yet: there is one
/// position and one calculation method, both already chosen in the app.
struct NextPrayerWidget: Widget {

    private let kind = "NextPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextPrayerProvider()) { entry in
            NextPrayerWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(l10n(.widgetNextPrayerName)))
        .description(Text(l10n(.widgetNextPrayerDescription)))
        .supportedFamilies(Self.supportedFamilies)
    }

    /// The Lock Screen families are iOS-only — macOS widgets live on the desktop and in
    /// Notification Center, where there is no accessory slot to put them in.
    private static var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium]
        #endif
    }

    /// The gallery's own strings, resolved before there is an entry to take a style from.
    private func l10n(_ key: L10nKey) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .main)
    }
}
