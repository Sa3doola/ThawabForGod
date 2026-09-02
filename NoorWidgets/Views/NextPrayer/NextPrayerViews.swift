//
//  NextPrayerViews.swift
//  NoorWidgets
//

import SwiftUI

/// The next prayer's *identity*: which one, and at what o'clock.
///
/// The three system families of the Next Prayer kind, together because they are one idea at three
/// sizes and the header is literally the same view in all three. What separates them is how much
/// room there is after it — the small has none, the medium spends it on the countdown, the large
/// spends it on the rest of the day.
///
/// The countdown is present but never the largest thing here. That is the whole line between this
/// kind and the countdown kind: a reader who wants the timer picks the widget whose timer fills it.

/// The header both larger families lead with: symbol, kicker, name, clock time.
private struct NextPrayerHeader: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style
    var nameStyle: AppTextStyle = .title3

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // The kicker is what makes the widget self-describing. On a Home Screen full of other
            // numbers, "Maghrib" over "18:15" is not obviously a prayer time.
            Label {
                Text(l10n.string(.nextPrayerLabel))
                    .appFont(.caption)
                    .textCase(.uppercase)
            } icon: {
                Image(systemName: day.upcoming.prayer.symbol)
                    .imageScale(.small)
            }
            .foregroundStyle(theme.textSecondary)

            Text(l10n.string(day.upcoming.prayer.labelKey))
                .appFont(nameStyle, weight: .semibold)
                .foregroundStyle(theme.textPrimary)

            Text(l10n.time(day.upcoming.date))
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The square: the header, with the countdown beneath it as a footnote.
struct NextPrayerSmallView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NextPrayerHeader(day: day, style: style)

            Spacer(minLength: AppSpacing.xs)

            CountdownText(to: day.upcoming.date)
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The wide one: the header on the leading side, the countdown large on the trailing side.
///
/// Side by side rather than stacked, which is what the width is for — the header is three short
/// lines and the countdown is one long one, so neither has to shrink to sit beside the other.
struct NextPrayerMediumView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            NextPrayerHeader(day: day, style: style)

            VStack(alignment: .trailing, spacing: 0) {
                Text(l10n.string(.widgetIn))
                    .appFont(.caption)
                    .foregroundStyle(theme.textSecondary)

                CountdownText(to: day.upcoming.date)
                    .appFont(.title, weight: .semibold)
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The tall one: the header, the countdown at display size, and the rest of the day under a rule.
struct NextPrayerLargeView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            NextPrayerHeader(day: day, style: style, nameStyle: .title2)

            CountdownText(to: day.upcoming.date)
                .appFont(.largeTitle, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            // The header pins to the top and the list to the bottom, so whatever height the family
            // actually gives us goes into the gap rather than into a band of nothing under the day.
            Spacer(minLength: AppSpacing.sm)

            Divider()
                .overlay(theme.separator)

            PrayerList(day: day, style: style, density: .roomy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
