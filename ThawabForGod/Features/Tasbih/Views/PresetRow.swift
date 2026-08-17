//
//  PresetRow.swift
//  ThawabForGod
//

import SwiftUI

/// One phrase in the tasbih list: the Arabic, its meaning where there is one, and what a lap is.
struct PresetRow: View {
    let dhikr: TasbihDhikr
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    arabicText

                    if let translation = dhikr.translation {
                        Text(translation)
                            .appFont(.footnote)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                target
            }
            .padding(16)
            .background(theme.surface, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// Forced right-to-left rather than left to inherit the screen's direction, for the same
    /// reason `DhikrCard` does it: the phrase is Arabic whatever language the interface is in, and
    /// an English reader's left-aligned paragraph would hang from the wrong edge.
    private var arabicText: some View {
        Text(dhikr.arabicText)
            .appFont(.title3)
            .foregroundStyle(theme.textPrimary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, AppLanguage.arabic.locale)
    }

    /// `×33`, in the reader's digits. The multiplication sign carries the meaning without needing
    /// a word, which keeps the row the same width in both languages.
    private var target: some View {
        Text("×\(l10n.string(dhikr.targetCount, grouped: false))")
            .appFont(.headline)
            .monospacedDigit()
            .foregroundStyle(theme.accent)
            .accessibilityLabel(l10n.string(.tasbihTargetLabel))
            .accessibilityValue(l10n.string(dhikr.targetCount, grouped: false))
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    VStack(spacing: 12) {
        PresetRow(
            dhikr: TasbihDhikr(
                id: "subhanallah",
                arabicText: "سُبْحَانَ اللَّهِ",
                translation: "Glory be to Allah",
                targetCount: 33
            ),
            action: {}
        )
        PresetRow(
            dhikr: TasbihDhikr(
                id: "astaghfirullah",
                arabicText: "أَسْتَغْفِرُ اللَّهَ",
                translation: nil,
                targetCount: 100
            ),
            action: {}
        )
    }
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
