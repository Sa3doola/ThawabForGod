//
//  NextPrayerSnapshot.swift
//  ThawabForGod
//

import Foundation

/// One moment as a widget will draw it.
///
/// Deliberately free of WidgetKit. The widget target conforms this to `TimelineEntry` in a
/// one-line extension — it already has the `date` that protocol asks for — which is what lets
/// the whole of the timeline logic live here, be compiled into the app, and be tested by a suite
/// that cannot import an extension target.
nonisolated struct NextPrayerSnapshot: Equatable, Sendable {

    /// When this snapshot becomes the current one. WidgetKit shows it from here until the next.
    let date: Date

    let content: Content

    /// How to draw it — read from the shared settings once, when the timeline is built.
    let style: Style

    /// What there is to show, including the two cases where the answer is "nothing".
    enum Content: Equatable, Sendable {

        /// A day's times, with the one being counted down to.
        case schedule(Day)

        /// No position has ever been captured. The widget says so and invites the reader to
        /// open the app.
        ///
        /// A case rather than a fallback, and this is the decision the whole slice turns on:
        /// Home may draw Makkah as a placeholder because the reader is looking at the screen
        /// and can see where it thinks they are. A Home Screen widget is glanced at, believed,
        /// and wrong all day. Same argument as `PrayerReminderPlanner`'s, one step further.
        case noLocation

        /// A latitude where the sun does not do what the arithmetic assumes — Adhan returns
        /// nothing for a polar day, and saying so is better than an empty timeline, which
        /// WidgetKit renders as a blank rectangle.
        case notComputable
    }

    /// The times a single entry is drawn from.
    struct Day: Equatable, Sendable {
        /// The prayer being counted down to. Carries `isTomorrow`, which is how the entry after
        /// Isha knows it is naming tomorrow's Fajr.
        let upcoming: UpcomingPrayer

        /// The list the medium and large families show, in order.
        let times: [PrayerTime]

        /// The marker whose window this moment falls in, if any — `nil` before the day's Fajr.
        let current: Prayer?
    }

    /// Everything about presentation that a widget process has to read out of shared storage
    /// rather than out of the environment.
    ///
    /// Gathered at build time rather than in a view body: the entry *is* the snapshot, and a
    /// view that re-read the store would be reading it at an unrelated moment, on a schedule
    /// WidgetKit decides.
    struct Style: Equatable, Sendable {
        let numberSystem: NumberSystem
        let clockFormat: ClockFormat
        let accent: AccentPalette
        let language: AppLanguage

        init(
            numberSystem: NumberSystem,
            clockFormat: ClockFormat,
            accent: AccentPalette,
            language: AppLanguage
        ) {
            self.numberSystem = numberSystem
            self.clockFormat = clockFormat
            self.accent = accent
            self.language = language
        }
    }
}
