//
//  OccasionRow.swift
//  ThawabForGod
//

import SwiftUI

/// One upcoming occasion: its name, when it falls in both calendars, how far away it is, and a
/// tint for its category.
struct OccasionRow: View {
    let occurrence: OccasionOccurrence
    let daysAway: Int
    let open: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Capsule()
                    .fill(occurrence.occasion.category.tint(in: theme))
                    .frame(width: 4)

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        titleAndDate
                        remaining
                    }
                } else {
                    titleAndDate
                    Spacer(minLength: 8)
                    remaining
                }

                Image(systemName: "chevron.forward")
                    .appFont(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityHidden(true)
            }
            // The tint bar is as tall as the words and no taller: a bare `Capsule` takes whatever
            // height it is offered.
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var titleAndDate: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l10n.string(occurrence.occasion.nameKey))
                .appFont(.body, weight: .medium)
                .foregroundStyle(theme.textPrimary)
            Text(dateLine)
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var remaining: some View {
        Text(l10n.daysAwayString(daysAway))
            .appFont(.footnote, weight: .medium)
            .foregroundStyle(theme.textSecondary)
    }

    /// `9–10 Muharram 1447 · 4 Jul`.
    private var dateLine: String {
        let hijri = OccasionDateText.hijri(
            first: occurrence.first.hijri,
            last: occurrence.last.hijri,
            localized: l10n.string,
            number: { l10n.string($0, grouped: $1) }
        )
        return HijriDateText.combined(hijri: hijri, gregorian: l10n.shortDateString(occurrence.first.gregorian))
    }
}
