//
//  PrayerTrackerSection.swift
//  ThawabForGod
//

import SwiftUI

/// Today's five, and the run of days behind them.
///
/// Five circles rather than a bare `3 / 5`, because the number on its own is a report and the
/// circles are the thing you actually use — marking a prayer is a one-tap job that should not
/// need a sheet opened first. The sheet is still where a *past* day is marked; this is today.
struct PrayerTrackerSection: View {
    let record: PrayerRecord
    let streak: Int
    let setCompleted: @MainActor @Sendable (Prayer, Bool) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            HStack(spacing: 2) {
                ForEach(PrayerRecord.trackable) { prayer in
                    TrackerCircle(
                        prayer: prayer,
                        isCompleted: record.isCompleted(prayer),
                        setCompleted: { setCompleted(prayer, $0) }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(theme.separator)
        }
    }

    private var header: some View {
        HStack {
            Text(l10n.string(.homeSectionPrayerTracker))
                .appFont(.headline, weight: .semibold)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 8)

            if streak > 0 {
                Label(
                    l10n.string(.prayerStreakLabel, l10n.string(streak, grouped: false)),
                    systemImage: "flame"
                )
                .appFont(.caption, weight: .medium)
                .foregroundStyle(theme.accent)
            }

            Text(
                l10n.string(
                    .activityProgress,
                    l10n.string(record.completedCount, grouped: false),
                    l10n.string(PrayerRecord.trackable.count, grouped: false)
                )
            )
            .appFont(.subheadline, weight: .semibold)
            .foregroundStyle(theme.textSecondary)
            .monospacedDigit()
        }
    }
}

/// One prayer's mark: a filled circle when it is done, an outline when it is not.
private struct TrackerCircle: View {
    let prayer: Prayer
    let isCompleted: Bool
    let setCompleted: @MainActor @Sendable (Bool) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    @ScaledMetric private var diameter: CGFloat = 36

    var body: some View {
        Button {
            setCompleted(!isCompleted)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .strokeBorder(isCompleted ? Color.clear : theme.separator, lineWidth: 1.5)
                        .background(
                            Circle().fill(isCompleted ? theme.accent : Color.clear)
                        )

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .appFont(.caption, weight: .bold)
                            .foregroundStyle(theme.surface)
                    }
                }
                .frame(width: diameter, height: diameter)

                Text(l10n.string(prayer.labelKey))
                    .appFont(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.string(prayer.labelKey))
        // Read as "selected" rather than as a button with a state buried in its label, which is
        // what a checkbox-shaped control is expected to say.
        .accessibilityAddTraits(isCompleted ? [.isButton, .isSelected] : .isButton)
    }
}
