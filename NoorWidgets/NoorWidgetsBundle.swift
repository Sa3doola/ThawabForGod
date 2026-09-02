//
//  NoorWidgetsBundle.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// Noor's widgets.
///
/// Four kinds. Three are one timeline seen three ways — what is next, how long is left, and the
/// whole day — and they are separate entries in the gallery rather than families of one widget
/// because a reader chooses between them by the question they are asking, and a widget that
/// answered all three would be largest at nothing.
///
/// `HijriDateWidget` is the fourth and the odd one, on a timeline of its own: it turns over at
/// midnight rather than at a prayer, and it is the only widget here that needs no position and so
/// has no state in which it cannot answer.
///
/// Nothing below the surface is duplicated. `NextPrayerProvider` — and `NextPrayerTimeline` under
/// it — serves the first three unchanged, so another prayer kind is a `Widget` and a set of views
/// with the arithmetic staying in one tested place.
@main
struct NoorWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
        PrayerCountdownWidget()
        AllPrayersWidget()
        HijriDateWidget()
    }
}
