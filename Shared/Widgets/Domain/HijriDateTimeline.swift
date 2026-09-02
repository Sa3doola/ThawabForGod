//
//  HijriDateTimeline.swift
//  ThawabForGod
//

import Foundation

/// Builds the date widget's timeline, without importing WidgetKit.
///
/// **One entry per day, at local midnight.** The prayer widgets break at prayer transitions
/// because that is when their answer changes; this one's answer changes when the civil day does,
/// which the Umm al-Qura approximation puts at midnight local time — not at sunset, and not at
/// UTC midnight. Getting that wrong would leave the widget a day out for part of every day, which
/// is the exact trap `HijriDateService` documents about reading components in UTC.
///
/// A fortnight of entries covers a fortnight of the extension never being woken. There is nothing
/// live on this widget — no countdown, no progress — so between midnights there is genuinely
/// nothing to redraw.
nonisolated struct HijriDateTimeline: Sendable {

    private let hijriDates: any HijriDateServicing
    private let settingsStore: any SettingsStore
    private let calendar: Calendar

    /// How many days of entries to hand WidgetKit at a time.
    ///
    /// Fourteen rather than one: an entry costs a few dozen bytes and the reload below is booked
    /// for the end of them anyway, so a phone that is never opened still shows the right date for
    /// two weeks rather than going stale tomorrow.
    private let horizon = 14

    /// - Parameter timeZone: the device's, and the calendar is Gregorian rather than
    ///   `Calendar.current` for the reason `PrayerTimeEngine` documents — a device set to the
    ///   Islamic calendar returns Hijri components, and "start of day" arithmetic on those is
    ///   not the civil midnight this widget turns over on.
    init(
        hijriDates: any HijriDateServicing,
        settingsStore: any SettingsStore,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.hijriDates = hijriDates
        self.settingsStore = settingsStore

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    /// The entries WidgetKit should render, in order, starting with one for `now`.
    ///
    /// Never empty. The first entry is `now` rather than this morning's midnight, because an
    /// entry dated in the past is one WidgetKit has to skip past before it draws anything.
    func entries(from now: Date) -> [HijriDateSnapshot] {
        let style = currentStyle()

        let midnights = (1..<horizon).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: now))
        }

        return ([now] + midnights).map { moment in
            HijriDateSnapshot(
                date: moment,
                hijri: hijriDates.hijriComponents(for: moment),
                events: hijriDates.islamicEvents(on: moment),
                style: style
            )
        }
    }

    /// When WidgetKit should come back for a new timeline: the midnight after the last entry, so
    /// the horizon rolls forward rather than running out.
    func reloadDate(after entries: [HijriDateSnapshot], from now: Date) -> Date {
        guard let last = entries.last?.date else {
            return calendar.startOfDay(for: now.addingTimeInterval(secondsPerDay))
        }

        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last))
            ?? last.addingTimeInterval(secondsPerDay)
    }

    private var secondsPerDay: TimeInterval { 24 * 60 * 60 }

    /// The presentation choices, read once per timeline.
    ///
    /// The same `NextPrayerSnapshot.Style` the prayer widgets carry, read the same way. A second
    /// style type would be a second place for the fallbacks to be got wrong, and this widget makes
    /// exactly the same three choices — digits, language, accent. The clock format is along for
    /// the ride; nothing here draws a time.
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
