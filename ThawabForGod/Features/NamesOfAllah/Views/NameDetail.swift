//
//  NameDetail.swift
//  ThawabForGod
//

import SwiftUI

/// One name, at full size, with everything the corpus knows about it.
///
/// Sections appear only when there is something in them, which matters more here than elsewhere:
/// an Arabic reader has no transliteration and no meaning to show, and *nobody* has an explanation
/// yet — see `Resources/Corpus/README.md`. Empty headings would advertise gaps rather than fill
/// them.
struct NameDetail: View {
    let name: DivineName

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headline

                if let meaning = name.meaning {
                    section(title: l10n.string(.namesMeaningLabel), body: meaning)
                }

                if let explanation = name.explanation {
                    section(title: l10n.string(.namesExplanationLabel), body: explanation)
                }

                if let reference = name.reference {
                    section(title: l10n.string(.namesReferenceLabel), body: reference)
                }

                verificationNotice
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.namesTitle))
    }

    /// The number, the name, and how to say it.
    private var headline: some View {
        VStack(spacing: 10) {
            Text(l10n.string(name.order, grouped: false))
                .appFont(.callout, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(theme.accent)

            // Forced right-to-left: the name is Arabic whatever language the interface is in.
            Text(name.arabic)
                .appFont(.largeTitle, weight: .bold)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, AppLanguage.arabic.locale)

            if let transliteration = name.transliteration {
                Text(transliteration)
                    .appFont(.title3)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(theme.accent)

            Text(body)
                .appFont(.body)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(theme.surface, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    /// The standing caveat, on the screen rather than in a settings page nobody opens — the same
    /// treatment the adhkar list gets, and for the same reason.
    private var verificationNotice: some View {
        Text(l10n.string(.namesVerificationNotice))
            .appFont(.footnote)
            .foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(theme.warning.opacity(0.12), in: .rect(cornerRadius: 12))
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        NameDetail(
            name: DivineName(
                id: 1,
                arabic: "الرَّحْمَنُ",
                transliteration: "Ar Rahmaan",
                meaning: "The Beneficent",
                explanation: nil,
                reference: "(1:3) (17:110)"
            )
        )
    }
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}
