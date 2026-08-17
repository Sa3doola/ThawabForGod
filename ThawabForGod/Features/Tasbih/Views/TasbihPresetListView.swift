//
//  TasbihPresetListView.swift
//  ThawabForGod
//

import SwiftUI

/// The phrases the counter offers.
///
/// Built from what the corpus returned rather than from a list in code, so adding a sixth preset
/// is a rebuild of `corpus.sqlite` and nothing else.
struct TasbihPresetListView: View {
    let viewModel: TasbihViewModel
    let coordinator: TasbihCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                content
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.tasbihTitle))
        // Re-runs on a language change, which re-fetches the translations.
        .task(id: l10n.language) { await viewModel.loadPresets(in: l10n.language) }
        // Pushes into the stack Home owns rather than opening one of its own. Two-way: a back
        // swipe writes `nil` through the binding and the coordinator follows.
        .navigationDestination(item: openDhikr) { dhikr in
            TasbihCounterView(viewModel: viewModel, dhikr: dhikr)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.presetsPhase {
        case .loading:
            ProgressView(l10n.string(.tasbihLoading))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 48)

        case .ready(let presets):
            ForEach(presets) { dhikr in
                PresetRow(dhikr: dhikr) { coordinator.open(dhikr) }
            }

        case .unavailable:
            InlineNotice(message: l10n.string(.tasbihUnavailable))
        }
    }

    /// Built here rather than reached for with `@Bindable`, because the coordinator exposes its
    /// selection read-only — so dismissal by swipe goes through the same method a Back button
    /// would call.
    private var openDhikr: Binding<TasbihDhikr?> {
        Binding(
            get: { coordinator.openDhikr },
            set: { if $0 == nil { coordinator.closeDhikr() } }
        )
    }
}

/// Builds a view model over the real corpus and a throwaway in-memory store.
///
/// Outside the `#Preview` macro on purpose: `TasbihProgressRepository`'s initialiser is generated
/// by `@ModelActor`, and macro-generated members are not visible from inside another macro's
/// expansion — constructing it in the preview body fails to compile with "no accessible
/// initializers". One level of indirection is the whole fix.
@MainActor
func previewTasbihViewModel() -> TasbihViewModel {
    let persistence = try! PersistenceController(inMemory: true)

    return TasbihViewModel(
        useCase: TasbihUseCase(
            catalog: TasbihCatalogRepository(database: CorpusDatabase(name: "corpus")),
            progress: TasbihProgressRepository(modelContainer: persistence.container)
        ),
        // The real reporter would need a configured TipKit datastore, which a preview has not got.
        tips: NoTasbihTipReporting()
    )
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        TasbihPresetListView(
            viewModel: previewTasbihViewModel(),
            coordinator: TasbihCoordinator()
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
