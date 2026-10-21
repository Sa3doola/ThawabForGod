//
//  SelectedDayPanel.swift
//  ThawabForGod
//

import SwiftUI

/// What the selected day holds: the Moon at Maghrib and the occasions that fall on it.
struct SelectedDayPanel: View {
    let viewModel: HijriCalendarViewModel

    @Environment(\.theme) private var theme
    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            moonRow
            Divider().overlay(theme.separator)
            occasionsList
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var moonRow: some View {
        let info = viewModel.moon(on: viewModel.selectedDay)
        let phase = l10n.string(info.phase.labelKey)
        let percent = l10n.string(.moonPercentValue, l10n.string(Int((info.illuminatedFraction * 100).rounded())))

        return HStack(spacing: 14) {
            MoonView(
                illuminatedFraction: info.illuminatedFraction,
                isWaxing: info.isWaxing,
                hemisphere: viewModel.hemisphere,
                accessibilityText: l10n.string(.moonAccessibilityLabel, phase, percent)
            )
            .frame(width: 48, height: 48)
            .padding(6)
            .background { DayRampBackground(stop: DayRamp.stop(for: .isha)) }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.string(.calendarMoonHeading))
                    .appFont(.caption)
                    .foregroundStyle(theme.textSecondary)
                Text(l10n.string(.calendarMoonSummary, phase, percent))
                    .appFont(.body, weight: .medium)
                    .foregroundStyle(theme.textPrimary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var occasionsList: some View {
        let occasions = viewModel.occasions(on: viewModel.selectedDay)

        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.string(.calendarOccasionsHeading))
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)

            if occasions.isEmpty {
                Text(l10n.string(.calendarNoOccasions))
                    .appFont(.body)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(occasions, id: \.id) { occasion in
                    HStack(spacing: 8) {
                        Text(l10n.string(occasion.nameKey))
                            .appFont(.body, weight: .medium)
                            .foregroundStyle(theme.textPrimary)
                        if occasion.isRecurring {
                            Text(l10n.string(.calendarRecurring))
                                .appFont(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }
        }
    }
}
