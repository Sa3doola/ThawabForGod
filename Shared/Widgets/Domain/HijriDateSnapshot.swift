//
//  HijriDateSnapshot.swift
//  ThawabForGod
//

import Foundation

/// One day as a date widget will draw it.
///
/// Deliberately free of WidgetKit, for the reason `NextPrayerSnapshot` is: the extension conforms
/// it to `TimelineEntry` in a one-line extension, which is what lets the timeline that produces
/// these be compiled into the app and tested by a suite that cannot import an extension target.
///
/// **No `noLocation` case.** That is the whole difference between this snapshot and the prayer
/// one: a date needs no position, so there is no state in which this widget cannot answer. Umm
/// al-Qura is a table inside ICU and the conversion is arithmetic — offline, always available,
/// and the same everywhere in a given time zone.
nonisolated struct HijriDateSnapshot: Equatable, Sendable {

    /// When this snapshot becomes the current one — local midnight, since that is when the civil
    /// Hijri day rolls over. See `HijriDateService` on why the time zone is not decoration.
    let date: Date

    let hijri: HijriDate

    /// What falls on this day, if anything. Empty on most days.
    ///
    /// Carried on the entry rather than looked up in the view, because the view is redrawn on
    /// WidgetKit's schedule and would be asking about the wrong day between entries.
    let events: [IslamicEvent]

    let style: NextPrayerSnapshot.Style

    init(date: Date, hijri: HijriDate, events: [IslamicEvent], style: NextPrayerSnapshot.Style) {
        self.date = date
        self.hijri = hijri
        self.events = events
        self.style = style
    }
}
