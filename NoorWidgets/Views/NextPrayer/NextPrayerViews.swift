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
/// All three share `NextPrayerHeader` — symbol, kicker, name, clock time — which is what makes
/// them read as one widget at three sizes rather than three drawings of the same data.
///
/// **Only the small and the large carry a countdown, and neither makes it the largest thing.**
/// That is the line between this kind and `PrayerCountdownWidget`: a reader who wants the timer
/// picks the widget whose timer fills it. The medium has none at all, because the strip it gained
/// wants the height more than a second reading of a number another kind exists to show.

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

/// The wide one: which prayer is next across the top, the whole day as a strip underneath.
///
/// **No countdown on this family.** It carries `NextPrayerHeader` — symbol, kicker, name, clock
/// time — and hands "how long is left" to `PrayerCountdownWidget`, which is a whole kind built
/// around that question. Sharing the header is what makes the small, medium and large read as one
/// widget at three sizes rather than three drawings of the same data.
///
/// The consequence is that the upcoming prayer's clock time appears twice: once on the header's
/// third line and again in the strip, picked out by its tile. That is a real cost in a 360-point
/// widget and it is accepted knowingly — the header would not be the header without the time, and
/// the strip cannot leave a hole where the next prayer is.
///
/// **Stacked rather than set side by side**, because the day is a *sequence* and a sequence wants
/// the full width — six equal columns of it, with the name above.
///
/// The day is the list the entry carries, which after Isha is *tomorrow's* — see
/// `NextPrayerTimeline`. Showing today's six times when the widget has already rolled over would
/// be six rows in the past.
struct NextPrayerMediumView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NextPrayerHeader(day: day, style: style)

            Divider()
                .overlay(theme.separator)
                .padding(.bottom, AppSpacing.xxs)

            DayStrip(day: day, style: style)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
