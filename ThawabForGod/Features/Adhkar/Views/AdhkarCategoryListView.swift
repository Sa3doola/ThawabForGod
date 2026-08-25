//
//  AdhkarCategoryListView.swift
//  ThawabForGod
//

import SwiftUI

/// The adhkar the app carries, by heading.
///
/// Only two today — morning and evening — because that is all the bundled corpus holds. The list
/// is built from what the database returned rather than from `AdhkarCategory.allCases`, so it
/// can never offer a heading with nothing behind it.
struct AdhkarCategoryListView: View {
    let viewModel: AdhkarViewModel
    let coordinator: AdhkarCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                content
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.adhkarTitle))
        .task { await viewModel.loadCategories() }
        // Pushes into the stack this tab owns, rather than opening one of its own. Two-way: a
        // back swipe writes `nil` through the binding and the coordinator follows.
        .navigationDestination(item: openCategory) { category in
            AdhkarReadingView(viewModel: viewModel, category: category)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.categoriesPhase {
        case .loading:
            // Labelled rather than a bare spinner: VoiceOver announces something other than
            // "in progress", and the label carries the language the reader chose.
            ProgressView(l10n.string(.adhkarLoading))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 48)

        case .ready(let categories):
            ForEach(categories) { category in
                CategoryRow(category: category) {
                    coordinator.open(category)
                }
            }

            verificationNotice

        case .unavailable:
            InlineNotice(message: l10n.string(.adhkarUnavailable))
        }
    }

    /// The standing caveat about this content.
    ///
    /// It stays until someone has read the corpus against a printed Hisn al-Muslim — see
    /// `Resources/Corpus/README.md`. Presenting unchecked religious text as settled is the one
    /// failure mode this feature cannot recover from, so the admission is on the screen rather
    /// than in a settings page nobody opens.
    private var verificationNotice: some View {
        Text(l10n.string(.adhkarVerificationNotice))
            .appFont(.footnote)
            .foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.lg)
            .background(theme.warning.opacity(0.12), in: .rect(cornerRadius: AppRadius.md))
            .padding(.top, 8)
    }

    /// Built here rather than reached for with `@Bindable`, because the coordinator exposes its
    /// selection read-only — so dismissal by swipe goes through the same method a Back button
    /// would call.
    private var openCategory: Binding<AdhkarCategory?> {
        Binding(
            get: { coordinator.openCategory },
            set: { if $0 == nil { coordinator.closeCategory() } }
        )
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        AdhkarCategoryListView(
            viewModel: AdhkarViewModel(
                useCase: GetAdhkarUseCase(
                    repository: AdhkarRepository(database: CorpusDatabase(name: "corpus"))
                )
            ),
            coordinator: AdhkarCoordinator()
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
