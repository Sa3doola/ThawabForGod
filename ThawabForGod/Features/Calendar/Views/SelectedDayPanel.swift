//
//  SelectedDayPanel.swift
//  ThawabForGod
//

import SwiftUI

/// What the selected day holds: the Moon at Maghrib and the occasions that fall on it.
struct SelectedDayPanel: View {
    let viewModel: HijriCalendarViewModel
    let showMoon: () -> Void
    let showOccasion: (IslamicOccasion) -> Void

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
        MoonCard(
            info: viewModel.moon(on: viewModel.selectedDay),
            hemisphere: viewModel.hemisphere,
            showDetails: showMoon
        )
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
                    Button { showOccasion(occasion) } label: {
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
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
