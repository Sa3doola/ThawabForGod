//
//  HijriDateProvider.swift
//  NoorWidgets
//

import WidgetKit

extension HijriDateSnapshot: TimelineEntry {}

/// Feeds the date widget, and does no thinking of its own.
///
/// Everything it needs is synchronous and needs no permission: `HijriDateService` is a table
/// inside ICU, and the presentation choices come out of the App Group's `UserDefaults`. Unlike
/// `NextPrayerProvider` it never has to ask where the reader is, which is why this one has no
/// state in which it cannot answer.
struct HijriDateProvider: TimelineProvider {

    private let timeline: HijriDateTimeline

    init() {
        timeline = HijriDateTimeline(
            hijriDates: HijriDateService(),
            settingsStore: UserDefaultsSettingsStore(defaults: SharedDefaults.store)
        )
    }

    func placeholder(in context: Context) -> HijriDateSnapshot {
        timeline.entries(from: Date())[0]
    }

    func getSnapshot(in context: Context, completion: @escaping (HijriDateSnapshot) -> Void) {
        completion(timeline.entries(from: Date())[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HijriDateSnapshot>) -> Void) {
        let now = Date()
        let entries = timeline.entries(from: now)

        completion(
            Timeline(entries: entries, policy: .after(timeline.reloadDate(after: entries, from: now)))
        )
    }
}
