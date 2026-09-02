//
//  PrayerList.swift
//  NoorWidgets
//

import SwiftUI

/// The day as a column of rows: symbol, name, and the time at the far end.
///
/// **Five rows, not six.** Sunrise is on the app's own day strip because it is the marker readers
/// most often mistake for a prayer and the app is the right place to say what it is — but a widget
/// has no room to say it, and the sixth row costs the other five the height they need on a small
/// family. `Prayer.isObligatory` is the filter, and this is the single place the rule lives.
///
/// A column rather than the six-across strip this replaces. A row is read left to right — name,
/// then time — which is how a schedule is read on paper, and it degrades by *dropping* rather than
/// by shrinking: the small family loses the symbols, and nothing has to fit "Maghrib" over
/// "6:15 PM" into sixty points.
struct PrayerList: View {

    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style
    var density: Density = .regular

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    /// How much of a row there is room for.
    ///
    /// The symbol is what goes first, because it is the only part carrying no information the row
    /// does not already state — the name is beside it.
    enum Density {
        /// The small family: names and times, no symbols, rows as tight as they go.
        case compact
        /// The medium family.
        case regular
        /// The large family, where the rows can breathe.
        case roomy

        var showsSymbols: Bool { self != .compact }

        var rowSpacing: CGFloat {
            switch self {
            case .compact: AppSpacing.xxs
            case .regular: AppSpacing.xs
            case .roomy: AppSpacing.sm
            }
        }

        var textStyle: AppTextStyle {
            switch self {
            case .compact: .caption
            case .regular: .footnote
            case .roomy: .subheadline
            }
        }
    }

    var body: some View {
        VStack(spacing: density.rowSpacing) {
            ForEach(rows) { time in
                row(time)
            }
        }
    }

    /// The obligatory five, in the order the entry carries them — which is chronological.
    private var rows: [PrayerTime] {
        day.times.filter(\.prayer.isObligatory)
    }

    /// The row drawn as the one the reader is in.
    ///
    /// The prayer whose window is *open*, not the one being counted down to. After Isha the list
    /// is tomorrow's and nothing is current, so the highlight falls back to the upcoming prayer —
    /// which is that day's Fajr, and the right row to pick out on a list of a day not yet begun.
    private var highlighted: Prayer {
        day.current ?? day.upcoming.prayer
    }

    private func row(_ time: PrayerTime) -> some View {
        let isCurrent = time.prayer == highlighted

        return HStack(spacing: AppSpacing.sm) {
            if density.showsSymbols {
                Image(systemName: time.prayer.symbol)
                    .imageScale(density == .roomy ? .medium : .small)
                    .foregroundStyle(isCurrent ? theme.accent : theme.textSecondary)
                    // A fixed box, so the names start on one edge whatever the symbol's own
                    // width — `moon.stars` is a good deal wider than `sun.max`, and a ragged
                    // left edge on five rows reads as a mistake.
                    .frame(width: symbolWidth, alignment: .center)
            }

            Text(l10n.string(time.prayer.labelKey))
                .appFont(density.textStyle, weight: isCurrent ? .semibold : .regular)
                .foregroundStyle(isCurrent ? theme.accent : theme.textPrimary)

            Spacer(minLength: AppSpacing.sm)

            Text(l10n.time(time.date))
                .appFont(density.textStyle, weight: isCurrent ? .semibold : .regular)
                .foregroundStyle(isCurrent ? theme.accent : theme.textSecondary)
                // Monospaced digits so the times line up down the column: proportional digits put
                // the colon of "6:15" and "12:30" in different places, and five rows of that reads
                // as five separate labels rather than one table.
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var symbolWidth: CGFloat {
        density == .roomy ? AppSpacing.xl : AppSpacing.lg
    }
}
