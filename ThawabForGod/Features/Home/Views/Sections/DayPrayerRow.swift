//
//  DayPrayerRow.swift
//  ThawabForGod
//

import SwiftUI

/// The whole day along the bottom of the card: six markers, the next one picked out, the ones
/// behind us dimmed.
///
/// **Two layouts, chosen by type size rather than by measurement.** At ordinary sizes the six
/// entries divide the width evenly, which is what makes the row read as a timeline. At an
/// accessibility size six entries cannot share a phone's width without truncating a name or a
/// time, and truncating either is worse than scrolling — so the row becomes scrollable instead.
/// `ViewThatFits` could pick between them, but only by measuring an ideal width that an evenly
/// divided grid does not really have; the type size is the thing that actually decides, so it
/// is what the code asks about.
///
/// **A grid rather than an `HStack`, because only one of them actually divides evenly.** This
/// row was an `HStack` of entries each carrying `.frame(maxWidth: .infinity)`, which reads like
/// six equal columns and is not: a stack gives every child its ideal width first and shares out
/// only what is *left over*. "Dhuhr" over "12:25 PM" has a wider ideal than "Asr" over "3:47 PM",
/// so it kept that head start and the columns came out uneven — with the marker capsule a
/// different width depending on which prayer was next. `GridItem(.flexible())` divides the whole
/// width instead, so the columns are equal whatever the times happen to read.
struct DayPrayerRow: View {
    let state: NextPrayerState

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) { entries(distributed: false) }
            }
        } else {
            LazyVGrid(columns: columns, alignment: .center, spacing: 0) {
                entries(distributed: true)
            }
        }
    }

    /// One equal column per marker.
    ///
    /// `minimum: 0` so the division stays equal at every width rather than falling back on
    /// `GridItem`'s default floor — the entries shrink their own text, which is the behaviour
    /// this row wants when space runs short.
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: 2),
            count: max(state.times.count, 1)
        )
    }

    /// - Parameter distributed: whether each entry should fill its column. It is the entry that
    ///   carries the frame, not the `ForEach` — and filling matters for more than the text: the
    ///   capsule behind the next prayer is drawn on this frame, so without it the highlight
    ///   would hug the label instead of matching the column beside it.
    @ViewBuilder
    private func entries(distributed: Bool) -> some View {
        ForEach(state.times) { time in
            DayPrayerEntry(
                time: time,
                isUpcoming: state.isUpcoming(time.prayer),
                isCurrent: state.isCurrent(time.prayer),
                hasPassed: state.hasPassed(time.prayer)
            )
            .frame(maxWidth: distributed ? .infinity : nil)
        }
    }
}

/// One marker: a symbol, a name, and a time, stacked so the two labels never compete for width.
private struct DayPrayerEntry: View {
    let time: PrayerTime
    let isUpcoming: Bool
    let isCurrent: Bool
    let hasPassed: Bool

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: time.prayer.symbol)
                .imageScale(.medium)
                .foregroundStyle(tint)

            Text(l10n.string(time.prayer.labelKey))
                .appFont(.caption, weight: isUpcoming ? .semibold : .regular)
                .foregroundStyle(tint)

            Text(l10n.timeString(time.date))
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
        }
        // Six columns on a 4.7-inch phone leave about fifty points each, and "Sunrise" and
        // "7:35 PM" both want more than that. Shrinking is the right answer where wrapping is
        // not: a hyphenated "Sun-rise" stacked over a two-line time turns a timeline into a
        // paragraph. The floor is high enough to stay legible, and beyond it the row scrolls
        // instead — see the type-size branch above.
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .multilineTextAlignment(.center)
        .padding(.vertical, 12)
        // Horizontal padding on this row is width taken straight out of the labels: eight points
        // a side is ninety-six across six entries, which on a 4.7-inch phone is a third of the
        // card. At that width "4:52 AM" cannot shrink far enough to fit and truncates instead.
        // The vertical padding costs nothing and stays.
        .padding(.horizontal, 3)
        .background(isUpcoming ? theme.accent.opacity(0.15) : .clear, in: .capsule)
        // Behind us, and not the thing being counted down to — the day reads left to right (or
        // right to left) as it is lived, with what is done receding.
        .opacity(hasPassed && !isUpcoming ? 0.45 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isUpcoming || isCurrent ? .isSelected : [])
    }

    private var tint: Color {
        isUpcoming || isCurrent ? theme.accent : theme.textPrimary
    }
}
