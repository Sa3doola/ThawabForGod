//
//  NextPrayerWidget.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// Which prayer is next, and at what o'clock.
///
/// **The kind string is not to be changed.** A widget already on somebody's Home Screen is bound
/// to it, so renaming this would silently blank every installed copy — which is why the two kinds
/// added alongside it are additions rather than a rename of this one.
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
        .configurationDisplayName(Text(WidgetGalleryText.string(.widgetNextPrayerName)))
        .description(Text(WidgetGalleryText.string(.widgetNextPrayerDescription)))
        .supportedFamilies(Self.supportedFamilies)
    }

    /// The Lock Screen families are iOS-only — macOS widgets live on the desktop and in
    /// Notification Center, where there is no accessory slot to put them in.
    private static var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

/// Picks the layout for the family. Everything around it — the theme, the digits, the ramp, the
/// deep link, and the two states that are not a schedule — is `WidgetChrome`'s.
struct NextPrayerWidgetView: View {

    let entry: NextPrayerSnapshot

    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetChrome(entry: entry) { day in
            switch family {
            case .systemMedium:
                NextPrayerMediumView(day: day, style: entry.style)

            case .systemLarge, .systemExtraLarge:
                NextPrayerLargeView(day: day, style: entry.style)

            #if os(iOS)
            case .accessoryCircular:
                NextPrayerAccessoryCircularView(day: day, style: entry.style)

            case .accessoryRectangular:
                NextPrayerAccessoryRectangularView(day: day, style: entry.style)

            case .accessoryInline:
                NextPrayerAccessoryInlineView(day: day, style: entry.style)
            #endif

            default:
                NextPrayerSmallView(day: day, style: entry.style)
            }
        }
    }
}

/// The gallery's own strings, resolved before there is an entry to take a style from.
///
/// A widget's display name and description are read by the system when the gallery is built, which
/// is a moment no timeline has run — so `WidgetLocalization`, which is constructed from an entry's
/// style, cannot be used. `L10nKey` still makes a missing key a compile error, which is the part
/// of the app's rule that matters here.
enum WidgetGalleryText {
    static func string(_ key: L10nKey) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .main)
    }
}
