//
//  PrayerTimesList.swift
//  ThawabForGod
//

import SwiftUI

/// The day's six markers, in order, with the current one picked out.
struct PrayerTimesList: View {
    let day: HomeViewModel.Day

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(day.schedule.times.enumerated()), id: \.element.id) { index, time in
                PrayerRow(
                    time: time,
                    isCurrent: day.isCurrent(time.prayer),
                    isUpcoming: day.isUpcoming(time.prayer)
                )

                if index < day.schedule.times.count - 1 {
                    Divider().overlay(theme.separator)
                }
            }
        }
        .background(theme.surface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(theme.separator)
        }
    }
}

/// One marker. Name on the leading edge, time on the trailing edge — stated as leading and
/// trailing rather than left and right, which is what makes the row mirror for Arabic.
private struct PrayerRow: View {
    let time: PrayerTime
    let isCurrent: Bool
    let isUpcoming: Bool

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Text(l10n.string(time.prayer.labelKey))
                .appFont(.body, weight: isCurrent ? .semibold : .regular)
                .foregroundStyle(isCurrent ? theme.accent : theme.textPrimary)

            if isCurrent {
                Text(l10n.string(.currentPrayerLabel))
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.15), in: .capsule)
            }

            Spacer(minLength: 8)

            Text(l10n.timeString(time.date))
                .appFont(.body, weight: isUpcoming ? .semibold : .regular)
                .foregroundStyle(isUpcoming ? theme.accent : theme.textSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
