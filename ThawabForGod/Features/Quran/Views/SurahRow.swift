//
//  SurahRow.swift
//  ThawabForGod
//

import SwiftUI

/// One chapter in the list: its place, its names, and what it is.
///
/// A `Button` rather than a tappable `VStack`, like every other tappable thing in the app — it
/// buys the pressed state, the VoiceOver trait and keyboard focus without any of them being
/// rebuilt by hand.
struct SurahRow: View {
    let surah: Surah
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                number
                names
                Spacer(minLength: 8)
                detail
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// Its place in the mushaf, which is how most readers refer to a chapter.
    private var number: some View {
        Text(l10n.string(surah.id, grouped: false))
            .appFont(.footnote, weight: .semibold)
            .foregroundStyle(theme.accent)
            .frame(width: 34, height: 34)
            .background(theme.accent.opacity(0.12), in: .circle)
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Arabic whatever the interface language is, so VoiceOver is told which language to
            // read it in. A name is one word, so unlike a verse it needs no paragraph direction
            // pinned — the bidi algorithm places it correctly on either screen.
            Text(surah.arabicName)
                .appFont(.title3)
                .foregroundStyle(theme.textPrimary)
                .environment(\.locale, AppLanguage.arabic.locale)

            Text(l10n.language == .arabic ? surah.transliteration : surah.englishName)
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var detail: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(l10n.string(surah.revelationPlace == .meccan ? .quranMeccan : .quranMedinan))
                .appFont(.caption, weight: .medium)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(theme.separator.opacity(0.35), in: .capsule)

            HStack(spacing: 4) {
                Text(l10n.string(.quranVersesLabel))
                Text(l10n.string(surah.verseCount, grouped: false))
            }
            .appFont(.caption)
            .foregroundStyle(theme.textSecondary)
        }
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    SurahRow(
        surah: Surah(
            id: 2,
            arabicName: "البقرة",
            transliteration: "Al-Baqara",
            englishName: "The Cow",
            verseCount: 286,
            revelationPlace: .medinan,
            revelationOrder: 87,
            bismillah: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"
        ),
        action: {}
    )
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
