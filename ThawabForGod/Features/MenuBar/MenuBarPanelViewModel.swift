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

    /// Marks a prayer as prayed. Optional so the panel's tests — which are about the title, the
    /// ticker and the day — need no store at all; the action is simply absent without one.
    @ObservationIgnored private let tracker: PrayerTrackerUseCase?

    /// What has been marked today, so the action can say whether it has already been used. Read
    /// on `refresh()`, which runs every time the panel opens.
    private(set) var record: PrayerRecord?

    init(
        timeline: NextPrayerTimeline,
        l10n: LocalizationManager,
        tracker: PrayerTrackerUseCase? = nil,
        now: Date = Date()
    ) {
        self.timeline = timeline
        self.l10n = l10n
        self.tracker = tracker
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

    // MARK: Logging from the panel

    /// The prayer the panel offers to mark, or `nil` when there is none to offer.
    ///
    /// **The prayer whose window is open, not the one being counted down to.** The countdown
    /// names what is *next*, and nobody has prayed a prayer whose time has not come — offering to
    /// log it would be offering to record something untrue. Before the day's Fajr there is no
    /// open window at all, and the action is absent rather than disabled.
    var loggablePrayer: Prayer? {
        guard let prayer = currentPrayer, prayer.isObligatory, tracker != nil else { return nil }
        return prayer
    }

    /// Whether that prayer has already been marked today — what turns the row into a tick.
    var hasLoggedCurrentPrayer: Bool {
        guard let prayer = loggablePrayer, let record else { return false }
        return record.isCompleted(prayer)
    }

    /// Marks the open prayer, and re-reads what is stored rather than assuming the write landed.
    ///
    /// A toggle rather than a one-way mark, so a mis-tap in a panel that closes on the next click
    /// is undone by opening it again and tapping the same row.
    func toggleLoggingCurrentPrayer() async {
        guard let tracker, let prayer = loggablePrayer else { return }

        try? await tracker.setCompleted(!hasLoggedCurrentPrayer, of: prayer, on: now)
        await loadRecord()
    }

    /// Reads today's marks. Called when the panel opens, which is the only time anyone is looking
    /// at them — the status item itself says nothing about what has been prayed.
    func loadRecord() async {
        guard let tracker else { return }
        record = try? await tracker.record(on: now)
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

    /// The status item as its parts, at whichever rung the bar and the preference allow.
    ///
    /// The countdown here is the *brief* one — `h:mm` above the hour, `mm:ss` inside it — padded
    /// into a slot measured from the widest string this locale can produce. Both halves of that
    /// are what stop the item twitching; see `MenuBarStatusSlot`, which carries the argument.
    ///
    /// When there is no schedule there is no countdown, so the item falls to its symbol and the
    /// notice becomes the tooltip. That is the same honesty the widget shows: an item that said
    /// nothing at all would look like an app that had crashed.
    func statusTitle(rung: MenuBarStatusRung) -> MenuBarStatusTitle {
        guard case .schedule(let day) = snapshot.content, let remaining else {
            return MenuBarStatusTitle(
                symbol: statusSymbol,
                text: "",
                tooltip: noticeKey.map { l10n.string($0) } ?? l10n.string(.appName)
            )
        }

        let name = l10n.string(day.upcoming.prayer.labelKey)
        let time = MenuBarStatusSlot.padded(
            l10n.briefCountdownString(remaining),
            toVisibleLength: statusSlotLength
        )

        var parts: [String] = []
        if rung.showsName { parts.append(name) }
        if rung.showsTime { parts.append(time) }

        return MenuBarStatusTitle(
            symbol: rung.showsSymbol ? statusSymbol : nil,
            text: parts.joined(separator: " "),
            // The full thing, at every rung — which is what makes dropping the name cost
            // nothing, since it is still one hover away.
            tooltip: "\(name) \(l10n.countdownString(remaining))"
        )
    }

    /// How many characters wide the countdown's slot is, for the digits in use now.
    ///
    /// Recomputed rather than stored because the number system is a live preference: a reader who
    /// switches to Arabic-Indic digits mid-afternoon gets the slot re-measured on the next beat,
    /// which is at most a second away.
    var statusSlotLength: Int {
        MenuBarStatusSlot.visibleLength(
            of: l10n.briefCountdownString(MenuBarStatusSlot.widestInterval)
        )
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
    ///
    /// Outside the final hour the beat is not a fixed half-minute but *however long is left of
    /// the current minute*, because that is exactly when the label's last digit changes. A fixed
    /// interval cannot manage that: at thirty seconds the displayed minute is stale for up to
    /// half a minute and then jumps, and at one second the machine is woken sixty times a minute
    /// to redraw a string that changed once. Sleeping to the boundary is both fewer wakeups than
    /// either and always right.
    var tickInterval: Duration {
        guard let remaining else { return .seconds(30) }
        guard remaining >= 60 * 60 else { return .seconds(1) }

        // The countdown floors, so it reads a new minute when `remaining` next passes a multiple
        // of sixty. Never zero — a beat of no duration would spin.
        let toBoundary = remaining.truncatingRemainder(dividingBy: 60)

        return .seconds(max(1, Int(toBoundary.rounded(.up))))
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
