//
//  PrayerScheduleMediumView.swift
//  NoorWidgets
//

import SwiftUI

/// The wide one: the countdown on the leading side, the whole day beside it.
///
/// The day is the list the entry carries, which after Isha is *tomorrow's* — see
/// `NextPrayerTimeline`. Showing today's six times under a countdown to a seventh that is not
/// among them would be six rows in the past and an answer matching none of them.
struct PrayerScheduleMediumView: View {

    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            upcoming
            Divider()
            list
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var upcoming: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(l10n.string(day.upcoming.prayer.labelKey))
                    .appFont(.subheadline, weight: .semibold)
            } icon: {
                Image(systemName: day.upcoming.prayer.symbol)
            }
            .foregroundStyle(theme.accent)

            CountdownText(to: day.upcoming.date)
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(l10n.time(day.upcoming.date))
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Six rows in two columns. A single column would need a font nobody can read at this height,
    /// and dropping a prayer to fit would make the widget lie about the day.
    private var list: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, pair in
                GridRow {
                    ForEach(pair, id: \.id) { time in
                        row(time)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ time: PrayerTime) -> some View {
        let isCurrent = time.prayer == day.current

        return HStack(spacing: 4) {
            Text(l10n.string(time.prayer.labelKey))
                .appFont(.caption, weight: isCurrent ? .semibold : .regular)
                .foregroundStyle(isCurrent ? theme.accent : theme.textSecondary)

            Spacer(minLength: 2)

            Text(l10n.time(time.date))
                .appFont(.caption, weight: isCurrent ? .semibold : .regular)
                .foregroundStyle(isCurrent ? theme.accent : theme.textPrimary)
        }
    }

    /// The day's markers, paired into rows of two in chronological order.
    private var rows: [[PrayerTime]] {
        stride(from: 0, to: day.times.count, by: 2).map { start in
            Array(day.times[start..<min(start + 2, day.times.count)])
        }
    }
}
