//
//  NextPrayerState.swift
//  ThawabForGod
//

import Foundation

/// Everything the next-prayer card draws, except the part that changes every second.
///
/// The countdown is deliberately *not* in here. Observation tracks reads per property, so a value
/// that ticks once a second belongs on its own property — folding it into this one would
/// invalidate the whole card, six prayer entries and all, sixty times a minute. What lives here
/// is what changes when a *prayer* changes, which is a few times a day.
///
/// It is a Domain value rather than a view-model nested type so the card's rules — which entry is
/// next, which have passed, how full the bar is — can be tested without a view or a clock.
nonisolated struct NextPrayerState: Equatable, Sendable {

    /// The day the entries below belong to.
    let schedule: PrayerSchedule

    /// The marker whose window we are inside, or `nil` before the day's Fajr.
    let currentPrayer: Prayer?

    /// What the countdown is running towards, which after Isha is tomorrow's Fajr.
    let upcoming: UpcomingPrayer

    /// The near end of the window the progress bar fills, if it could be resolved.
    ///
    /// Optional because it must never be able to take the card down with it: it is decoration,
    /// and the hours before Fajr need a *second* day's times to anchor it, which is one more
    /// thing that can fail than the card itself needs.
    let previous: PassedPrayer?

    init(
        schedule: PrayerSchedule,
        currentPrayer: Prayer?,
        upcoming: UpcomingPrayer,
        previous: PassedPrayer?
    ) {
        self.schedule = schedule
        self.currentPrayer = currentPrayer
        self.upcoming = upcoming
        self.previous = previous
    }

    // MARK: The day's entries

    /// The six markers, in order.
    var times: [PrayerTime] { schedule.times }

    func isCurrent(_ prayer: Prayer) -> Bool {
        currentPrayer == prayer
    }

    /// Whether this entry is the one being counted down to.
    ///
    /// The `isTomorrow` guard is the whole point: after Isha the countdown targets the *next*
    /// day's Fajr, and wrapping today's Fajr entry in the highlight capsule would say the day is
    /// about to start rather than about to end.
    func isUpcoming(_ prayer: Prayer) -> Bool {
        !upcoming.isTomorrow && upcoming.prayer == prayer
    }

    /// Whether this entry is behind us, and should be drawn dimmed.
    ///
    /// Answered from `currentPrayer` rather than from a clock: the current marker is by
    /// definition the last one that has passed, so everything up to and including it is done and
    /// everything after it is not. That keeps the whole type free of `now`, which is what lets it
    /// be tested without one.
    func hasPassed(_ prayer: Prayer) -> Bool {
        guard let currentPrayer,
              let current = times.firstIndex(where: { $0.prayer == currentPrayer }),
              let subject = times.firstIndex(where: { $0.prayer == prayer }) else {
            // Before Fajr nothing today has passed yet.
            return false
        }

        return subject <= current
    }

    // MARK: The progress bar

    /// How long the window between the last marker and the next one is, or `nil` when the near
    /// end could not be resolved.
    var windowDuration: TimeInterval? {
        guard let previous else { return nil }

        let duration = upcoming.date.timeIntervalSince(previous.date)
        // Zero would divide, and negative would mean the two ends arrived out of order — which
        // can only happen if the schedules they came from disagree.
        return duration > 0 ? duration : nil
    }

    /// How much of the current window has elapsed, from the seconds still to go.
    ///
    /// Takes the remaining time rather than reading a clock so that the bar and the countdown are
    /// always drawn from the same instant — two independent reads of `Date()` one line apart can
    /// straddle a second and leave the two disagreeing.
    func progress(remaining: TimeInterval) -> Double {
        guard let windowDuration else { return 0 }

        return min(max(1 - (remaining / windowDuration), 0), 1)
    }
}
