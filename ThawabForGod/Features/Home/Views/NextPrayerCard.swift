//
//  NextPrayerCard.swift
//  ThawabForGod
//

import SwiftUI

/// The headline: which prayer is next, at what time, and how long is left.
struct NextPrayerCard: View {
    let viewModel: HomeViewModel
    let day: HomeViewModel.Day

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.string(.nextPrayerLabel))
                .appFont(.footnote, weight: .semibold)
                .foregroundStyle(theme.textSecondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline) {
                Text(l10n.string(day.upcoming.prayer.labelKey))
                    .appFont(.title, weight: .bold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 12)

                Text(l10n.timeString(day.upcoming.date))
                    .appFont(.title3, weight: .semibold)
                    .foregroundStyle(theme.accent)
            }

            CountdownLabel(viewModel: viewModel)

            if day.upcoming.isTomorrow {
                Text(l10n.string(.tomorrowLabel))
                    .appFont(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(theme.separator)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The ticking half, split out on purpose.
///
/// Observation tracks reads per property, and this is the only view that reads `countdown` —
/// so the once-a-second change invalidates this label alone, not the card and not the list.
private struct CountdownLabel: View {
    let viewModel: HomeViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Text(l10n.countdownString(viewModel.countdown))
            .appFont(.largeTitle, weight: .semibold)
            .foregroundStyle(theme.textPrimary)
            // Digits vary in width as they tick; a monospaced set stops the label jittering.
            .monospacedDigit()
    }
}
