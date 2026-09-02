//
//  Countdown.swift
//  NoorWidgets
//

import SwiftUI

/// A live countdown, guarded.
///
/// `Text(timerInterval:)` rather than a formatted string, and that is the one deliberate departure
/// from the app's rule that every countdown goes through `LocalizationManager.countdownString(_:)`.
/// A widget is redrawn only when its timeline says so, so a formatted string would need an entry a
/// minute — sixty wakes an hour, which is how an extension loses its refresh budget. The system's
/// timer text animates on its own and costs nothing. What it does not do is take a `NumberSystem`,
/// so the digits come from the locale the chrome puts in the environment.
///
/// The clamp: the form requires a range whose lower bound is not after its upper. An entry's own
/// moment is always strictly before the prayer it counts down to — `nextPrayer(at:)` uses a strict
/// comparison — but the *rendering* moment is whenever the system decides, which can be a shade
/// past the boundary while the next entry is still being swapped in.
///
/// A `Text` rather than a `View`, because the inline Lock Screen family concatenates it with a
/// label and `+` is defined on `Text` alone. Wrapping it in a view first would leave nothing to
/// concatenate — and interpolating it into a string would freeze the timer at render time, which
/// is the whole thing this is here to avoid.
enum Countdown {
    static func text(to date: Date) -> Text {
        let now = Date()

        guard date > now else { return Text(verbatim: "00:00") }

        return Text(timerInterval: now...date, countsDown: true)
    }
}

/// `Countdown.text(to:)` where a view is what is wanted.
struct CountdownText: View {
    let to: Date

    var body: some View {
        Countdown.text(to: to)
    }
}

/// The stretch a progress view represents: from the marker before the upcoming prayer to the
/// upcoming prayer itself.
///
/// **Shared by the circular ring and the rectangular bar**, because both are
/// `ProgressView(timerInterval:)` over the same window and two copies of this arithmetic would be
/// two things to get wrong. The timer form is what makes either possible at all: every entry in
/// this timeline is built *at* a prayer transition — see `NextPrayerTimeline` — so a computed
/// fraction would be zero in every entry that ever rendered, and the bar would sit permanently
/// empty. The system drains the timer form on its own between redraws.
///
/// The previous marker is read out of the entry's own list rather than off the clock: a view
/// redrawn on WidgetKit's schedule cannot ask the wall clock and get an answer that stays true.
///
/// After Isha there is no earlier marker in the list, because the list is *tomorrow's* and the
/// upcoming prayer is its Fajr. The night before is a day earlier than the night after by a couple
/// of minutes, so tomorrow's Isha shifted back twenty-four hours is where tonight's wait began —
/// close enough for a ring, and honest about being derived rather than measured.
enum PrayerWindow {
    static func range(for day: NextPrayerSnapshot.Day) -> ClosedRange<Date> {
        let end = day.upcoming.date
        let secondsPerDay: TimeInterval = 24 * 60 * 60

        let start = day.times.last { $0.date < end }?.date
            ?? day.times.last?.date.addingTimeInterval(-secondsPerDay)
            ?? end.addingTimeInterval(-secondsPerDay)

        // `ProgressView` traps on a reversed range, and the fallback above is arithmetic on times
        // this view did not compute. Cheaper to clamp than to reason about every latitude.
        return start < end ? start...end : end.addingTimeInterval(-1)...end
    }
}
