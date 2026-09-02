//
//  NextPrayerViews.swift
//  NoorWidgets
//

import SwiftUI

/// The next prayer's *identity*: which one, and at what o'clock.
///
/// The three system families of the Next Prayer kind, together because they are one idea at three
/// sizes. What separates them is how much room there is after the name — the small has none, the
/// medium spends it on the day as a strip, the large on the day as a list.
///
/// The small and the large share `NextPrayerHeader`, whose third line is the upcoming prayer's
/// clock time. The medium builds its own two-line header instead, because its strip already picks
/// that time out in a tile and a 360-point widget cannot afford to print it twice.
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

/// The wide one: what is next across the top, the whole day as a strip underneath.
///
/// **Stacked rather than set side by side.** The two halves were a countdown column and the header
/// beside it, and neither got the width it wanted: the day is a *sequence*, and a sequence wants
/// the full width — so it gets the whole row, six equal columns of it, and the countdown gets the
/// line above.
///
/// The header does not repeat the upcoming prayer's clock time. It is in the strip below, picked
/// out by the tile, so printing it twice in a 360-point widget would spend the one line this
/// layout has to give — which is why this family builds its own header rather than taking
/// `NextPrayerHeader`, whose third line is exactly that time.
///
/// The kicker sits at the far end of the name's own line rather than on a line of its own: it is
/// what makes the widget self-describing on a Home Screen full of other numbers, and the row it
/// shares had the width going spare.
///
/// The day is the list the entry carries, which after Isha is *tomorrow's* — see
/// `NextPrayerTimeline`. Showing today's six times under a countdown to a seventh that is not
/// among them would be six rows in the past and an answer matching none of them.
struct NextPrayerMediumView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            upcoming

            // The header pins to the top and the strip to the bottom, so whatever height the
            // family actually gives us goes into the gap between them rather than into a band of
            // nothing under the day.
            Spacer(minLength: AppSpacing.sm)

            Divider()
                .overlay(theme.separator)
                .padding(.bottom, AppSpacing.xxs)

            DayStrip(day: day, style: style)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Which prayer, and how long is left. Two lines, both leading — the countdown is why anyone
    /// looks at this widget, so it is the one thing drawn large.
    private var upcoming: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Label {
                    Text(l10n.string(day.upcoming.prayer.labelKey))
                        .appFont(.subheadline, weight: .semibold)
                } icon: {
                    Image(systemName: day.upcoming.prayer.symbol)
                }
                .foregroundStyle(theme.accent)

                Spacer(minLength: AppSpacing.xs)

                Text(l10n.string(.nextPrayerLabel))
                    .appFont(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            CountdownText(to: day.upcoming.date)
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
