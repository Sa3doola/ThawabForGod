//
//  NextPrayerProvider.swift
//  NoorWidgets
//

import WidgetKit

/// `NextPrayerSnapshot` is already shaped like a timeline entry — it has the `date` the protocol
/// asks for — so the conformance is a declaration and nothing more.
///
/// This one line is the entire reason the timeline logic lives in `Shared/` instead of here: the
/// app's test target cannot import an extension, so anything defined in this folder is untestable
/// by construction. `NextPrayerTimelineTests` covers the part that can be got wrong.
extension NextPrayerSnapshot: TimelineEntry {}

/// Feeds the widget, and does no thinking of its own.
///
/// Everything it needs is synchronous: `GetPrayerScheduleUseCase` is `nonisolated` arithmetic
/// over Adhan, and the position and preferences come out of the App Group's `UserDefaults`.
/// There is no `await` anywhere in a widget refresh, and no network — which is what lets the
/// completion handlers below be called on the spot.
///
/// It never asks CoreLocation. A widget may not, so it reads what the app last resolved; see
/// `SettingsStore.bestKnownCoordinates`.
struct NextPrayerProvider: TimelineProvider {

    private let timeline: NextPrayerTimeline

    init() {
        let store = UserDefaultsSettingsStore(defaults: SharedDefaults.store)

        timeline = NextPrayerTimeline(
            schedule: GetPrayerScheduleUseCase(
                repository: PrayerTimeRepository(engine: PrayerTimeEngine())
            ),
            settingsStore: store
        )
    }

    /// The grey shape in the widget gallery, and what is drawn while a real entry is being made.
    ///
    /// Real times rather than invented ones, because the placeholder is redacted by the system
    /// anyway and a reader flicking through the gallery should see a widget the right *size* —
    /// which depends on how long the strings are.
    func placeholder(in context: Context) -> NextPrayerSnapshot {
        timeline.entries(from: Date())[0]
    }

    func getSnapshot(in context: Context, completion: @escaping (NextPrayerSnapshot) -> Void) {
        completion(timeline.entries(from: Date())[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextPrayerSnapshot>) -> Void) {
        let now = Date()
        let entries = timeline.entries(from: now)

        completion(
            Timeline(entries: entries, policy: .after(timeline.reloadDate(after: entries, from: now)))
        )
    }
}
