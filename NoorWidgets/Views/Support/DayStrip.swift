//
//  DayStrip.swift
//  NoorWidgets
//

import SwiftUI

/// The day's six markers across the width, in order.
///
/// **Six here, five in `PrayerList`, and the difference is the shape rather than an inconsistency.**
/// A strip is a *timeline* — it says where in the day the reader is, and Sunrise is one of the
/// marks that says it, which is why the app's own `DayPrayerRow` carries it too. A column of rows
/// is a *schedule*, a list of things to be done, and Sunrise is not one of them.
///
/// A `LazyVGrid` of flexible columns rather than an `HStack` of entries, for the reason
/// `DayPrayerRow` records in the app: a stack hands every child its ideal width first and shares
/// out only the remainder, so "Sunrise" over "6:33 AM" keeps a head start on "Asr" over "4:32 PM"
/// and the columns come out ragged — with the tile behind the next prayer a different width
/// depending on which prayer that is. Flexible columns divide the whole width, so they are equal
/// whatever the times happen to read.
///
/// The marker picked out is the **upcoming** one, not the current one. That is the opposite of
/// `PrayerList`'s rule and deliberate: this strip sits under a countdown, and the tile has to be on
/// the marker the countdown is running towards or the two halves of the widget disagree about what
/// they are describing.
struct DayStrip: View {

    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(day.times) { time in
                entry(time)
            }
        }
    }

    /// `minimum: 0` so the division stays equal at every width rather than falling back on
    /// `GridItem`'s default floor — the entries shrink their own text instead, which at six
    /// columns in a 360-point widget is what has to happen.
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: 2),
            count: max(day.times.count, 1)
        )
    }

    /// One marker: name, symbol, time — the symbol between the two pieces of text rather than
    /// above both, so the words sit at the outside of the cell where they have room to shrink
    /// into, and the column reads name-then-time down the strip.
    private func entry(_ time: PrayerTime) -> some View {
        let isUpcoming = time.prayer == day.upcoming.prayer

        return VStack(spacing: AppSpacing.xxs) {
            Text(l10n.string(time.prayer.labelKey))
                .appFont(.caption, weight: isUpcoming ? .semibold : .regular)
                .foregroundStyle(isUpcoming ? theme.accent : theme.textSecondary)

            Image(systemName: time.prayer.symbol)
                .imageScale(.small)
                .foregroundStyle(isUpcoming ? theme.accent : theme.textPrimary)

            Text(l10n.time(time.date))
                .appFont(.caption, weight: isUpcoming ? .semibold : .regular)
                .foregroundStyle(isUpcoming ? theme.accent : theme.textPrimary)
        }
        // Six columns of a 360-point widget are sixty points each, and "Sunrise" over "12:59 PM"
        // wants more than that. Shrinking beats wrapping: a hyphenated name over a two-line time
        // turns a timeline into a paragraph, and the row has one line of height to give.
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .multilineTextAlignment(.center)
        .padding(.vertical, AppSpacing.xs)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        // A tile around its own cell rather than a pill inside it — the strip reads as six cells
        // of one object, which is the same call `DayPrayerRow` makes in the app. The ring carries
        // it rather than the fill: on the day ramp the palette is inverted, and a wash at the
        // opacity that reads on the app's near-black background disappears entirely on amber.
        .background(
            isUpcoming ? theme.accent.opacity(0.15) : .clear,
            in: .rect(cornerRadius: AppRadius.sm)
        )
        .overlay {
            if isUpcoming {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .strokeBorder(theme.accent, lineWidth: 1)
            }
        }
        // Behind us, and receding. Nothing is dimmed after Isha — the strip is *tomorrow's*, so
        // none of it has passed.
        .opacity(hasPassed(time) ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isUpcoming ? .isSelected : [])
    }

    /// Whether this marker is behind the one being counted down to.
    ///
    /// Compared against the upcoming prayer rather than against `Date()`, because a widget view
    /// is redrawn on WidgetKit's schedule rather than on the clock's — asking the wall clock here
    /// would give an answer that goes stale between entries. The upcoming prayer is the entry's
    /// own definition of "now", and it is exact: an entry exists per prayer transition.
    ///
    /// After Isha, when the strip is tomorrow's, the upcoming prayer is that day's Fajr and so
    /// nothing is behind it — which is the right answer.
    private func hasPassed(_ time: PrayerTime) -> Bool {
        time.date < day.upcoming.date
    }
}
