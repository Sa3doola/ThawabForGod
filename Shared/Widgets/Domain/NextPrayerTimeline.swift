//
//  NextPrayerTimeline.swift
//  ThawabForGod
//

import Foundation

/// Builds the whole of a widget's timeline, without importing WidgetKit.
///
/// **One entry per prayer transition, not one per minute.** A widget cannot be woken sixty times
/// an hour, and it does not need to be: the countdown on screen is a system-rendered timer text
/// that animates on its own, so the only moments the *content* changes are the moments a prayer
/// arrives. Six or seven entries cover a whole day.
///
/// Everything it needs is synchronous and process-agnostic — `GetPrayerScheduleUseCase` is
/// `nonisolated` arithmetic over Adhan, and the position and preferences come out of the App
/// Group's `UserDefaults`. Nothing here asks CoreLocation, because a widget may not.
nonisolated struct NextPrayerTimeline: Sendable {

    private let schedule: GetPrayerScheduleUseCase
    private let settingsStore: any SettingsStore
    private let calendar: Calendar

    /// - Parameter timeZone: the device's, and the calendar is built here rather than taken from
    ///   `Calendar.current` for the reason `PrayerTimeEngine` documents — a device set to the
    ///   Islamic calendar returns Hijri components, and day arithmetic on those is nonsense.
    init(
        schedule: GetPrayerScheduleUseCase,
        settingsStore: any SettingsStore,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.schedule = schedule
        self.settingsStore = settingsStore

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    /// The entries WidgetKit should render, in order, starting with one for `now`.
    ///
    /// Never empty. Every failure this can meet — no position, a latitude the arithmetic cannot
    /// answer for — becomes an entry that says so, because an empty timeline is a blank
    /// rectangle on somebody's Home Screen with no way to find out why.
    func entries(from now: Date) -> [NextPrayerSnapshot] {
        let style = currentStyle()

        guard let coordinates = settingsStore.bestKnownCoordinates else {
            return [NextPrayerSnapshot(date: now, content: .noLocation, style: style)]
        }

        let config = settingsStore.storedCalculationConfig ?? .default

        guard let today = try? schedule.schedule(for: coordinates, date: now, config: config) else {
            return [NextPrayerSnapshot(date: now, content: .notComputable, style: style)]
        }

        // `now`, then every marker still ahead of it today. Each is a moment the answer to
        // "which prayer is next" changes, and there are no others.
        let transitions = [now] + today.times.map(\.date).filter { $0 > now }

        let snapshots = transitions.compactMap { moment in
            snapshot(at: moment, coordinates: coordinates, config: config, style: style)
        }

        // Only reachable if every one of today's remaining markers failed to resolve, which
        // needs the day to be computable and the next day not to be. Still not an empty
        // timeline.
        guard !snapshots.isEmpty else {
            return [NextPrayerSnapshot(date: now, content: .notComputable, style: style)]
        }

        return snapshots
    }

    /// When WidgetKit should come back for a new timeline.
    ///
    /// The prayer the last entry counts down to — after Isha that is tomorrow's Fajr, so the
    /// extension is woken once a day at dawn and not otherwise. A timeline with nothing to count
    /// down to is retried in an hour rather than never: the reader may be finishing onboarding
    /// right now, and a widget that gave up would stay wrong until something else happened to
    /// reload it.
    func reloadDate(after entries: [NextPrayerSnapshot], from now: Date) -> Date {
        guard case .schedule(let day)? = entries.last?.content else {
            return now.addingTimeInterval(60 * 60)
        }

        return day.upcoming.date
    }

    // MARK: Building one entry

    private func snapshot(
        at moment: Date,
        coordinates: Coordinates,
        config: CalculationConfig,
        style: NextPrayerSnapshot.Style
    ) -> NextPrayerSnapshot? {
        guard let upcoming = try? schedule.upcomingPrayer(
            for: coordinates, at: moment, config: config
        ) else {
            return nil
        }

        // After Isha the list shown alongside the countdown is tomorrow's, because that is the
        // day the countdown is now pointing into. Showing today's would put six times in the
        // past under a countdown to a seventh that is not among them.
        let listDay = upcoming.isTomorrow
            ? calendar.date(byAdding: .day, value: 1, to: moment) ?? moment
            : moment

        guard let times = try? schedule.schedule(
            for: coordinates, date: listDay, config: config
        ) else {
            return nil
        }

        return NextPrayerSnapshot(
            date: moment,
            content: .schedule(
                NextPrayerSnapshot.Day(
                    upcoming: upcoming,
                    times: times.times,
                    current: upcoming.isTomorrow ? nil : times.currentPrayer(at: moment)
                )
            ),
            style: style
        )
    }

    /// The presentation choices, read once per timeline.
    ///
    /// Each falls back the way the app's own managers do — an unset or unrecognised value means
    /// the user has never chosen, and the device decides. The language is the *process's*, which
    /// in an extension is the extension's own bundle, and correct: both bundles carry the same
    /// string catalog and iOS gives them the same preferred localization.
    private func currentStyle() -> NextPrayerSnapshot.Style {
        let language = AppLanguage.current()

        return NextPrayerSnapshot.Style(
            numberSystem: settingsStore.string(for: .numberSystem)
                .flatMap(NumberSystem.init(rawValue:)) ?? .preferred(for: language),
            clockFormat: settingsStore.string(for: .clockFormat)
                .flatMap(ClockFormat.init(rawValue:)) ?? .fallback,
            accent: settingsStore.string(for: .accentPalette)
                .flatMap(AccentPalette.init(rawValue:)) ?? .fallback,
            language: language
        )
    }
}
