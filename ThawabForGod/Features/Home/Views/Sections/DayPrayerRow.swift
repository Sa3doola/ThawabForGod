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
/// divided stack does not really have; the type size is the thing that actually decides, so it
/// is what the code asks about.
struct DayPrayerRow: View {
    let state: NextPrayerState

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) { entries(distributed: false) }
            }
        } else {
            HStack(alignment: .top, spacing: 2) { entries(distributed: true) }
        }
    }

    /// - Parameter distributed: whether each entry should claim an equal share of the width. The
    ///   frame goes on the entries rather than on the `ForEach`, which a stack would otherwise
    ///   treat as a single child and stretch as one block.
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
        .padding(.vertical, 8)
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
