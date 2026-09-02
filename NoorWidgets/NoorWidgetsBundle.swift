//
//  NoorWidgetsBundle.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// Noor's widgets.
///
/// Three kinds over one timeline: what is next, how long is left, and the whole day. They are three
/// entries in the gallery rather than three families of one widget because a reader chooses between
/// them by the question they are asking, and a widget that answered all three would be largest at
/// nothing.
///
/// Nothing below the surface is tripled. `NextPrayerProvider` — and `NextPrayerTimeline` under it —
/// serves all three unchanged, so a fourth kind is a `Widget` and a set of views, and the
/// arithmetic stays in one tested place.
@main
struct NoorWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
        PrayerCountdownWidget()
        AllPrayersWidget()
    }
}
