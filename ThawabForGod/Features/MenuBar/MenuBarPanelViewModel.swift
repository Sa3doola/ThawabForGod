//
//  MenuBarPanelViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// What the status item shows, and what is inside the panel it opens.
///
/// It computes nothing about prayer times itself: `NextPrayerTimeline` already answers "which
/// prayer is next, what is today's list, and what if there is no position", and it answers it for
/// the widget too. Reusing it here means the menu bar and the Home Screen cannot disagree — the
/// same three states, resolved the same way, including the one where the honest answer is that
/// there is no position to work from.
///
/// This is the whole of the menu bar that a test can reach. `MenuBarController` is AppKit glue
/// around it — an `NSStatusItem` and an `NSPopover` — and holds no logic of its own.
///
/// **No `#if os(macOS)`, unlike everything else in this folder**, and the reason is the test run.
/// Nothing here imports AppKit, and the project's suite runs on the iOS simulator — so gating
/// this type would compile it out of the only place it is ever tested, and out of CI with it. The
/// cost is that the iOS build carries a type it never constructs, which is the same trade
/// `SettingsRoute.macIntegration` and `HomeShortcut`'s reserved cases already make.
@Observable
@MainActor
final class MenuBarPanelViewModel {

    private(set) var snapshot: NextPrayerSnapshot
    private(set) var now: Date

    @ObservationIgnored private let timeline: NextPrayerTimeline
    @ObservationIgnored private let l10n: LocalizationManager

    init(timeline: NextPrayerTimeline, l10n: LocalizationManager, now: Date = Date()) {
        self.timeline = timeline
        self.l10n = l10n
        self.now = now
        // Never empty — see `NextPrayerTimeline.entries(from:)`, which turns every failure it can
        // meet into an entry that says so.
        self.snapshot = timeline.entries(from: now)[0]
    }

    /// Recomputes from scratch. For a settings change, or a wake from sleep.
    func refresh(at date: Date = Date()) {
        now = date
        snapshot = timeline.entries(from: date)[0]
    }

    /// One beat of the clock.
    ///
    /// Moves `now` — which is all the countdown needs — and rebuilds the schedule only when the
    /// prayer being counted down to has actually arrived. Recomputing on every tick would run the
    /// solar arithmetic once a second to get the same answer sixty times a minute.
    func tick(_ date: Date) {
        now = date

        guard case .schedule(let day) = snapshot.content else {
            // Nothing to count down to. `noLocation` resolves when the app next resolves a
            // position, and that arrives as a `refresh(at:)`; retrying the whole timeline on a
            // one-second beat would be a busy loop over an answer that cannot have changed.
            return
        }

        if date >= day.upcoming.date {
            refresh(at: date)
        }
    }

    // MARK: The status item

    /// The SF Symbol beside the title, which is the only part of the status item that survives
    /// the user narrowing their menu bar.
    var statusSymbol: String {
        switch snapshot.content {
        case .schedule(let day): day.upcoming.prayer.symbol
        case .noLocation: "location.slash"
        case .notComputable: "sun.max.trianglebadge.exclamationmark"
        }
    }

    /// The text in the menu bar: the prayer, then how long is left.
    ///
    /// Through `LocalizationManager.countdownString(_:)` rather than a raw interpolation, and it
    /// earns it twice over here. The digit system is a choice separate from the language, and the
    /// value comes back wrapped in Unicode directional isolates — the menu bar is the one place
    /// in this app where an Arabic label sits directly beside English system items, which is
    /// exactly where the bidi algorithm would otherwise reorder `6:03:49` into `6:0 3:49`.
    ///
    /// `nil` when there is nothing to count down to; the symbol alone stands in.
    var statusTitle: String? {
        guard case .schedule(let day) = snapshot.content, let remaining else { return nil }

        return "\(l10n.string(day.upcoming.prayer.labelKey)) \(l10n.countdownString(remaining))"
    }

    /// Seconds until the next prayer, floored at zero.
    var remaining: TimeInterval? {
        guard case .schedule(let day) = snapshot.content else { return nil }

        return max(0, day.upcoming.date.timeIntervalSince(now))
    }

    /// How long to wait before redrawing.
    ///
    /// A second while the countdown reads in seconds, half a minute once it does not. An idle Mac
    /// has no business being woken sixty times a minute to redraw a label saying `4h 12m`, and
    /// the reader cannot see the difference — but in the last hour they can, and that is the hour
    /// the status item exists for.
    ///
    /// A pure function of the state, so it is testable without a clock.
    var tickInterval: Duration {
        guard let remaining, remaining < 60 * 60 else { return .seconds(30) }

        return .seconds(1)
    }

    // MARK: The panel

    /// The day's markers, or empty when there is no schedule.
    var times: [PrayerTime] {
        guard case .schedule(let day) = snapshot.content else { return [] }

        return day.times
    }

    var currentPrayer: Prayer? {
        guard case .schedule(let day) = snapshot.content else { return nil }

        return day.current
    }

    var upcoming: UpcomingPrayer? {
        guard case .schedule(let day) = snapshot.content else { return nil }

        return day.upcoming
    }

    /// What the panel says when there is no schedule to show, or `nil` when there is one.
    var noticeKey: L10nKey? {
        switch snapshot.content {
        case .schedule: nil
        case .noLocation: .widgetNoLocation
        case .notComputable: .widgetTimesUnavailable
        }
    }
}
