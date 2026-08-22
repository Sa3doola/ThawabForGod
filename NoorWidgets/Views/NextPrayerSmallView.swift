//
//  NextPrayerSmallView.swift
//  NoorWidgets
//

import SwiftUI

/// The square: which prayer, when, and how long left.
///
/// The countdown is a `Text(timerInterval:)` rather than a formatted string, and that is the one
/// deliberate departure from the app's rule that every countdown goes through
/// `LocalizationManager.countdownString(_:)`. A widget is redrawn only when its timeline says so,
/// so a formatted string would need an entry a minute — sixty wakes an hour, which is how an
/// extension loses its refresh budget. The system's timer text animates on its own and costs
/// nothing. What it does not do is take a `NumberSystem`, so the digits come from the locale the
/// parent puts in the environment.
struct NextPrayerSmallView: View {

    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text(l10n.string(day.upcoming.prayer.labelKey))
                    .appFont(.subheadline, weight: .semibold)
            } icon: {
                Image(systemName: day.upcoming.prayer.symbol)
            }
            .foregroundStyle(theme.accent)

            Spacer(minLength: 4)

            CountdownText(to: day.upcoming.date)
                .appFont(.title, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(l10n.time(day.upcoming.date))
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// A live countdown, guarded.
///
/// `Text(timerInterval:)` requires a range whose lower bound is not after its upper. The entry's
/// own moment is always strictly before the prayer it counts down to — `nextPrayer(at:)` uses a
/// strict comparison — but the *rendering* moment is whenever the system decides, which can be a
/// shade past the boundary while the next entry is still being swapped in. Clamping is cheaper
/// than reasoning about that window.
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
