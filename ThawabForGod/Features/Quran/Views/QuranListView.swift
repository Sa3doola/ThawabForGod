//
//  QuranListView.swift
//  ThawabForGod
//

import SwiftUI

/// The Quran tab: the 114 chapters, or the thirty parts, whichever the reader is looking for.
///
/// A segmented control rather than a second tab bar. The Quran is already a tab, and a `TabView`
/// inside a `TabView` is the nesting the tab-bar decision was made to end — see `AppTab`. The two
/// lists are the same act of choosing where to start reading, which is what a segmented control
/// is for and what a tab is not.
struct QuranListView: View {
    @Bindable var viewModel: QuranViewModel
    let coordinator: QuranCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                sectionPicker
                content
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.quranTitle))
        .task { await viewModel.loadList() }
        // Pushes into the stack this tab owns, rather than opening one of its own. Two-way: a
        // back swipe writes `nil` through the binding and the coordinator follows.
        .navigationDestination(item: openReading) { reading in
            ReaderView(viewModel: viewModel, reading: reading)
        }
    }

    private var sectionPicker: some View {
        Picker(l10n.string(.quranTitle), selection: $viewModel.section) {
            Text(l10n.string(.quranSectionSurahs)).tag(QuranViewModel.Section.surahs)
            Text(l10n.string(.quranSectionJuz)).tag(QuranViewModel.Section.juz)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.listPhase {
        case .loading:
            // Labelled rather than a bare spinner, so VoiceOver announces something other than
            // "in progress" and does it in the language the reader chose.
            ProgressView(l10n.string(.quranTitle))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 48)

        case .ready:
            switch viewModel.section {
            case .surahs:
                ForEach(viewModel.surahs) { surah in
                    SurahRow(surah: surah) { coordinator.open(.surah(surah.id)) }
                }

            case .juz:
                ForEach(viewModel.juz) { juz in
                    JuzRow(juz: juz) { coordinator.open(.juz(juz.number)) }
                }
            }

        case .unavailable:
            InlineNotice(message: l10n.string(.quranUnavailable))
        }
    }

    /// Built here rather than reached for with `@Bindable`, because the coordinator exposes its
    /// selection read-only — so dismissal by swipe goes through the same method a Back button
    /// would call.
    private var openReading: Binding<QuranReading?> {
        Binding(
            get: { coordinator.openReading },
            set: { if $0 == nil { coordinator.closeReading() } }
        )
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        QuranListView(
            viewModel: QuranViewModel(
                useCase: GetQuranUseCase(
                    repository: QuranRepository(database: CorpusDatabase(name: "quran"))
                )
            ),
            coordinator: QuranCoordinator()
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
