//
//  NextPrayerAccessoryViews.swift
//  NoorWidgets
//

#if os(iOS)
import SwiftUI
import WidgetKit

/// The Lock Screen slots that answer *which prayer, and when*.
///
/// None of them reads `theme`. The system draws every accessory family in a single tint —
/// `AccessoryWidgetBackground` and the vibrancy treatment ignore colour entirely — so an accent
/// chosen against the app's background means nothing behind a wallpaper, and asking for one here
/// would simply be ignored.
///
/// **No countdown in any of them, and no ring.** That is the split this kind exists for: the
/// reader who wants the timer has a whole widget of their own next to this one in the gallery, and
/// putting the timer here too would leave two entries nobody can tell apart.

/// The circle: the prayer's symbol, its name, its time.
///
/// Three lines in thirty points, so all three shrink rather than truncate — a clipped time is
/// unreadable and a clipped name is the wrong prayer.
struct NextPrayerAccessoryCircularView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: day.upcoming.prayer.symbol)
                .font(.caption2)

            Text(l10n.string(day.upcoming.prayer.labelKey))
                .font(.caption2)

            Text(l10n.time(day.upcoming.date))
                .font(.caption2)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(2)
        .background { AccessoryWidgetBackground() }
        .clipShape(.circle)
        // The three labels read as "sunset, Maghrib, 6:15 PM" one after the other, which is not a
        // sentence.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.string(day.upcoming.prayer.labelKey))
        .accessibilityValue(l10n.time(day.upcoming.date))
    }
}

/// The rectangle: a kicker, the prayer with its symbol, the clock time.
///
/// The kicker is what makes the slot self-describing — on a Lock Screen full of other widgets,
/// "Maghrib" over a number is not obviously a prayer time.
struct NextPrayerAccessoryRectangularView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(l10n.string(.nextPrayerLabel))
                .font(.caption2)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Label {
                Text(l10n.string(day.upcoming.prayer.labelKey))
            } icon: {
                Image(systemName: day.upcoming.prayer.symbol)
            }
            .font(.headline)

            Text(l10n.time(day.upcoming.date))
                .font(.caption)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The line above the clock. One string, and the system decides how much of it fits.
///
/// Only this kind has one. The inline family is a single truncated line, so a second entry in the
/// gallery drawing the same shape would be two rows the reader cannot tell apart.
struct NextPrayerAccessoryInlineView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        // A `Label`, so the slot gets the prayer's symbol — the inline family renders one, and
        // without it the line is bare text among a row of iconed complications.
        Label {
            Text(l10n.string(day.upcoming.prayer.labelKey) + " " + l10n.time(day.upcoming.date))
        } icon: {
            Image(systemName: day.upcoming.prayer.symbol)
        }
    }
}
#endif
