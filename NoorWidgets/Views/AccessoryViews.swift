//
//  AccessoryViews.swift
//  NoorWidgets
//

#if os(iOS)
import SwiftUI
import WidgetKit

/// The Lock Screen families, together because they are three sizes of one idea and none of them
/// is more than a few lines.
///
/// All three are drawn by the system in a single tint — `AccessoryWidgetBackground` and the
/// vibrancy treatment ignore colour entirely — so none of them reads `theme`. That is a real
/// constraint rather than an oversight: an accent chosen against the app's background means
/// nothing behind a wallpaper, and asking for one here would just be ignored.

/// The circle: the prayer's symbol, with the countdown beneath it.
struct AccessoryCircularView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: day.upcoming.prayer.symbol)
                .font(.caption)

            CountdownText(to: day.upcoming.date)
                .font(.caption2)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .widgetAccessoryBackground()
    }
}

/// The rectangle: name, time, and the countdown — the most a Lock Screen slot can carry.
struct AccessoryRectangularView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label {
                Text(l10n.string(day.upcoming.prayer.labelKey))
            } icon: {
                Image(systemName: day.upcoming.prayer.symbol)
            }
            .font(.headline)

            CountdownText(to: day.upcoming.date)
                .font(.title3)

            Text(l10n.time(day.upcoming.date))
                .font(.caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The line above the clock. One string, and the system decides how much of it fits.
struct AccessoryInlineView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        // Concatenated `Text` rather than interpolation: the timer half has to stay live, and
        // interpolating it into a string would freeze it at the moment this was rendered.
        Text(l10n.string(day.upcoming.prayer.labelKey) + " ") + Countdown.text(to: day.upcoming.date)
    }
}

private extension View {
    /// The system's own Lock Screen backdrop, where the family has one.
    @ViewBuilder
    func widgetAccessoryBackground() -> some View {
        background {
            AccessoryWidgetBackground()
        }
    }
}
#endif
