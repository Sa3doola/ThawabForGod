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
    let viewModel: NamesViewModel
    let coordinator: NamesCoordinator

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

                pager
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.namesTitle))
    }

    /// The two names either side of this one.
    ///
    /// **The ninety-nine are a sequence, and this is the screen where that matters.** A reader
    /// who has just read *Al-Wadud* is most often going to want *Al-Majid*, and without this the
    /// only route there is back to a grid of ninety-nine tiles to find the one after the one they
    /// were on. The grid is for arriving somewhere; this is for going on.
    ///
    /// Absent at either end rather than disabled, for the reason the hadith pager gives.
    @ViewBuilder
    private var pager: some View {
        let previous = viewModel.name(before: name)
        let next = viewModel.name(after: name)

        if previous != nil || next != nil {
            HStack(spacing: AppSpacing.md) {
                if let previous {
                    pageButton(.namesPrevious, symbol: "chevron.backward", isLeading: true) {
                        coordinator.open(previous)
                    }
                }

                if let next {
                    pageButton(.namesNext, symbol: "chevron.forward", isLeading: false) {
                        coordinator.open(next)
                    }
                }
            }
        }
    }

    private func pageButton(
        _ key: L10nKey,
        symbol: String,
        isLeading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLeading { Image(systemName: symbol) }
                Text(l10n.string(key))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !isLeading { Image(systemName: symbol) }
            }
            .appFont(.subheadline, weight: .semibold)
            .foregroundStyle(theme.accent)
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity)
            .appCard(radius: AppRadius.md)
            .appHover(radius: AppRadius.md)
        }
        .buttonStyle(.plain)
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
        .padding(AppSpacing.lg)
        .appCard(radius: AppRadius.md)
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
            .padding(AppSpacing.lg)
            .background(theme.warning.opacity(0.12), in: .rect(cornerRadius: AppRadius.md))
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
            ),
            viewModel: NamesViewModel(
                useCase: GetNamesUseCase(
                    repository: NamesRepository(database: CorpusDatabase(name: "corpus"))
                ),
                tips: NoNamesTipReporting()
            ),
            coordinator: NamesCoordinator()
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
