//
//  LocalizationGallery.swift
//  ThawabForGod
//

import SwiftUI

/// Developer screen for checking localization end to end: switching language re-renders
/// every string, mirrors the layout for Arabic, and re-formats dates through the locale;
/// switching the number system re-draws every digit.
struct LocalizationGallery: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection

    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { l10n.language },
            set: { l10n.select(language: $0) }
        )
    }

    private var numberSystemSelection: Binding<NumberSystem> {
        Binding(
            get: { l10n.numberSystem },
            set: { l10n.select(numberSystem: $0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                pickers
                strings
                numbers
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background)
    }

    private var pickers: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(l10n.string(.appName))
                .appFont(.largeTitle, weight: .bold)
                .foregroundStyle(theme.textPrimary)

            Picker(selection: languageSelection) {
                ForEach(AppLanguage.allCases) { language in
                    Text(l10n.string(language.labelKey)).tag(language)
                }
            } label: {
                Text(l10n.string(.languageLabel))
            }
            .pickerStyle(.segmented)

            Picker(selection: numberSystemSelection) {
                ForEach(NumberSystem.allCases) { system in
                    Text(l10n.string(system.labelKey)).tag(system)
                }
            } label: {
                Text(l10n.string(.numbersLabel))
            }
            .pickerStyle(.segmented)
        }
    }

    private var strings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.string(.settingsTitle))
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(theme.textPrimary)

            Text(l10n.string(.sampleGreeting))
                .appFont(.body)
                .foregroundStyle(theme.textPrimary)

            // Leading alignment plus a mirrored layout is the RTL check: in Arabic this
            // whole column should hug the right edge.
            Text(verbatim: layoutDirection == .rightToLeft ? "→ rightToLeft" : "leftToRight →")
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var numbers: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.string(.sampleCount))
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(theme.textPrimary)

            ForEach([1, 33, 99, 1_234], id: \.self) { value in
                Text(l10n.string(value))
                    .appFont(.title3)
                    .foregroundStyle(theme.accent)
            }

            Text(l10n.string(21.5, fractionDigits: 1))
                .appFont(.body)
                .foregroundStyle(theme.textSecondary)

            // Date formatting follows `\.locale`, which `.localized(_:)` sets.
            Text(Date(timeIntervalSince1970: 1_800_000_000), format: .dateTime.year().month().day())
                .appFont(.body)
                .foregroundStyle(theme.textSecondary)
        }
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()
    let localizationManager = LocalizationManager(
        settingsStore: settingsStore,
        numberFormatting: LocaleNumberFormattingService()
    )

    LocalizationGallery()
        .themed(ThemeManager(settingsStore: settingsStore))
        .localized(localizationManager)
}
