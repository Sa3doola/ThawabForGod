//
//  AllPrayersView.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// The whole day, and nothing else.
///
/// One view for all three families, because this widget *is* `PrayerList` — the only thing a
/// family decides is how much of a row there is room for, which is `PrayerList.Density`. A second
/// file per size would be three copies of a `VStack` that differ by a type ramp.
///
/// The day is the list the entry carries, which after Isha is *tomorrow's* — see
/// `NextPrayerTimeline`. Showing today's five times once the countdown has rolled over would be
/// five rows in the past under a widget claiming to be a day.
struct AllPrayersView: View {

    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack {
            // Centred in whatever height the family gives us rather than pinned to the top: five
            // rows do not fill a large family, and a block of nothing under the last one reads as
            // a list that was cut off.
            Spacer(minLength: 0)

            PrayerList(day: day, style: style, density: density)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var density: PrayerList.Density {
        switch family {
        case .systemSmall: .compact
        case .systemLarge, .systemExtraLarge: .roomy
        default: .regular
        }
    }
}
