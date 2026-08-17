//
//  LapProgress.swift
//  ThawabForGod
//

import SwiftUI

/// The two numbers that sit under the counter: what a lap is, and how many are done.
///
/// Both go through `LocalizationManager` ungrouped — they count things, and a thousands separator
/// would be wrong at any size a tasbih reaches.
struct LapProgress: View {
    let target: Int
    let completedLaps: Int

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            stat(label: l10n.string(.tasbihTargetLabel), value: target, tint: theme.textSecondary)
            stat(label: l10n.string(.tasbihLapsLabel), value: completedLaps, tint: theme.accent)
        }
    }

    private func stat(label: String, value: Int, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)

            Text(l10n.string(value, grouped: false))
                .appFont(.title3, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(theme.surface, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    LapProgress(target: 33, completedLaps: 2)
        .padding()
        .themed(ThemeManager(settingsStore: settingsStore))
        .localized(
            LocalizationManager(
                settingsStore: settingsStore,
                numberFormatting: LocaleNumberFormattingService(),
                timeFormatting: LocaleTimeFormattingService()
            )
        )
}
