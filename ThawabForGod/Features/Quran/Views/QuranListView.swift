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
    /// Passed straight through to `ReaderView`. This screen has no look of its own to configure —
    /// it holds it only because it is the view that builds the destination.
    let settings: ReaderSettings

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                continueReading
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
        // Its own task, and re-run on every appearance rather than once: the reader leaves this
        // screen to read and comes back with a new position and possibly new bookmarks, and
        // nothing pushes that back up through a repository.
        .task(id: coordinator.openReading) { await viewModel.loadProgress() }
        // Pushes into the stack this tab owns, rather than opening one of its own. Two-way: a
        // back swipe writes `nil` through the binding and the coordinator follows.
        .navigationDestination(item: openReading) { reading in
            ReaderView(
                viewModel: viewModel,
                coordinator: coordinator,
                settings: settings,
                reading: reading
            )
        }
    }

    private var sectionPicker: some View {
        Picker(l10n.string(.quranTitle), selection: $viewModel.section) {
            Text(l10n.string(.quranSectionSurahs)).tag(QuranViewModel.Section.surahs)
            Text(l10n.string(.quranSectionJuz)).tag(QuranViewModel.Section.juz)
            Text(l10n.string(.quranSectionBookmarks)).tag(QuranViewModel.Section.bookmarks)
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

            case .bookmarks:
                bookmarks
            }

        case .unavailable:
            InlineNotice(message: l10n.string(.quranUnavailable))
        }
    }

    /// The kept verses, or a line saying there are none yet.
    ///
    /// Empty is the state this list is in for every reader until they save something, so it says
    /// what to do rather than simply being blank.
    @ViewBuilder
    private var bookmarks: some View {
        if viewModel.bookmarks.isEmpty {
            InlineNotice(message: l10n.string(.quranBookmarksEmpty))
        } else {
            ForEach(viewModel.bookmarks) { bookmark in
                BookmarkRow(
                    bookmark: bookmark,
                    surah: viewModel.surah(bookmark.reference.surah)
                ) {
                    coordinator.open(bookmark.reference)
                }
            }
        }
    }

    /// Shown only once there is somewhere to continue to — see `ContinueReadingCard`.
    @ViewBuilder
    private var continueReading: some View {
        if let position = viewModel.lastRead {
            ContinueReadingCard(
                position: position,
                surah: viewModel.surah(position.reference.surah)
            ) {
                coordinator.open(position.reference)
            }
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

/// Outside the `#Preview` macro on purpose, for the reason `previewTasbihViewModel()` documents:
/// `QuranProgressRepository`'s initialiser is generated by `@ModelActor`, and macro-generated
/// members are not visible from inside another macro's expansion.
@MainActor
func previewQuranViewModel() -> QuranViewModel {
    let persistence = try! PersistenceController(inMemory: true)

    return QuranViewModel(
        useCase: GetQuranUseCase(
            repository: QuranRepository(database: CorpusDatabase(name: "quran"))
        ),
        progress: QuranProgressUseCase(
            repository: QuranProgressRepository(modelContainer: persistence.container)
        )
    )
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        QuranListView(
            viewModel: previewQuranViewModel(),
            coordinator: QuranCoordinator(),
            settings: ReaderSettings(settingsStore: settingsStore)
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
