//
//  AdhkarReadingView.swift
//  ThawabForGod
//

import SwiftUI

/// One category's adhkar, to be read and counted through.
///
/// The reload is keyed on the language rather than run once: changing language while the screen
/// is open re-fetches the translations and the citations in the new one, and because the counts
/// live in the view model rather than in these rows, the reader keeps their place through it.
struct AdhkarReadingView: View {
    let viewModel: AdhkarViewModel
    let category: AdhkarCategory

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    /// The reader's choice of what to see beside the Arabic, for this visit. Local `@State`
    /// because it is a preference about *this screen* — the view model is about the adhkar.
    @State private var showsTranslation = true
    @State private var showsTransliteration = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                content
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(category.titleKey))
        // SwiftUI cancels and re-runs this when the language changes, which is exactly the
        // re-fetch that is wanted — and cancels it outright when the screen goes away.
        .task(id: l10n.language) {
            await viewModel.load(category, language: l10n.language)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.readingPhase {
        case .loading:
            ProgressView(l10n.string(.adhkarLoading))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 48)

        case .ready(let adhkar) where adhkar.isEmpty:
            InlineNotice(message: l10n.string(.adhkarEmpty))

        case .ready(let adhkar):
            progressHeader

            if adhkar.contains(where: { $0.translation != nil }) {
                displayToggles(offersTransliteration: adhkar.contains { $0.transliteration != nil })
            }

            ForEach(adhkar) { dhikr in
                DhikrCard(
                    dhikr: dhikr,
                    counted: viewModel.repeats(of: dhikr),
                    showsTranslation: showsTranslation,
                    showsTransliteration: showsTransliteration,
                    onCount: { viewModel.countRepeat(of: dhikr) },
                    onReset: { viewModel.resetRepeats(of: dhikr) }
                )
            }

        case .unavailable:
            InlineNotice(message: l10n.string(.adhkarUnavailable))
        }
    }

    /// How far through the category the reader is.
    ///
    /// Both numbers go through `LocalizationManager`, ungrouped — they count items, and a
    /// thousands separator would be wrong at any size the corpus will ever reach.
    private var progressHeader: some View {
        HStack(spacing: 12) {
            Text(l10n.string(.adhkarProgressLabel))
                .appFont(.subheadline)
                .foregroundStyle(theme.textSecondary)

            Spacer()

            Text(tally)
                .appFont(.subheadline, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(
                    viewModel.completedCount == viewModel.totalCount ? theme.success : theme.accent
                )
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private var tally: String {
        let done = l10n.string(viewModel.completedCount, grouped: false)
        let total = l10n.string(viewModel.totalCount, grouped: false)
        return "\(done) / \(total)"
    }

    /// What to show beside the Arabic. Absent entirely for an Arabic reader, for whom there is
    /// no translation and nothing to transliterate into.
    private func displayToggles(offersTransliteration: Bool) -> some View {
        VStack(spacing: 8) {
            Toggle(l10n.string(.adhkarShowTranslation), isOn: $showsTranslation)

            if offersTransliteration {
                Toggle(l10n.string(.adhkarShowTransliteration), isOn: $showsTransliteration)
            }
        }
        .appFont(.subheadline)
        .tint(theme.accent)
        .padding(14)
        .background(theme.surface, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        AdhkarReadingView(
            viewModel: AdhkarViewModel(
                useCase: GetAdhkarUseCase(
                    repository: AdhkarRepository(database: CorpusDatabase(name: "corpus"))
                )
            ),
            category: .morning
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
