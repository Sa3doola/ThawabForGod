//
//  CountdownViews.swift
//  NoorWidgets
//

import SwiftUI

/// How long is left, and nothing competing with it.
///
/// The three system families of the countdown kind. The timer is the largest thing on all three —
/// that is the entire difference between this kind and the next-prayer kind, which carries the
/// same number as a footnote. A reader who put this on their Home Screen asked "how long", and
/// every other line here exists to say what the number is counting towards.

/// `MAGHRIB IN` — the kicker that says what is elapsing.
///
/// A format string with the prayer's name in it rather than two concatenated `Text`s, because
/// Arabic puts the name after the preposition rather than before it and concatenation would fix
/// the order at the wrong one.
private struct CountdownKicker: View {
    let prayer: Prayer
    let style: NextPrayerSnapshot.Style
    var uppercased: Bool = true

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        Label {
            Text(String(format: l10n.string(.widgetPrayerIn), l10n.string(prayer.labelKey)))
                .appFont(.caption)
                .textCase(uppercased ? .uppercase : nil)
        } icon: {
            Image(systemName: "clock")
                .imageScale(.small)
        }
        .foregroundStyle(theme.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// The clock time the countdown lands on, under it.
private struct CountdownFooter: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        Label {
            Text(l10n.time(day.upcoming.date))
                .appFont(.footnote)
                .monospacedDigit()
        } icon: {
            Image(systemName: day.upcoming.prayer.symbol)
                .imageScale(.small)
        }
        .foregroundStyle(theme.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// The square and the wide one, which are the same three lines at two widths.
///
/// One view rather than two, because the difference between them is a type size the family already
/// decides — splitting it would be two files that have to be changed together for ever.
struct CountdownCompactView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    /// `.title` on the small family, `.largeTitle` on the medium — the medium has the width for
    /// `1:21:06` at display size and the small does not.
    var timerStyle: AppTextStyle = .title

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            CountdownKicker(prayer: day.upcoming.prayer, style: style)

            CountdownText(to: day.upcoming.date)
                .appFont(timerStyle, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            CountdownFooter(day: day, style: style)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The tall one: the prayer's symbol above everything, centred, and the timer as the whole point
/// of the widget.
///
/// Centred where the other two are leading-aligned, and deliberately: a large family given three
/// short lines and left-aligned is a column of text with a hole beside it. Centred, the symbol
/// reads as an emblem and the widget as one object.
struct CountdownLargeView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer(minLength: 0)

            Image(systemName: day.upcoming.prayer.symbol)
                .appFont(.largeTitle)
                .foregroundStyle(theme.accent)

            Text(String(format: l10n.string(.widgetPrayerIn), l10n.string(day.upcoming.prayer.labelKey)))
                .appFont(.headline)
                .foregroundStyle(theme.textSecondary)

            CountdownText(to: day.upcoming.date)
                .appFont(.largeTitle, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()

            Text(String(format: l10n.string(.widgetAtTime), l10n.time(day.upcoming.date)))
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()

            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
