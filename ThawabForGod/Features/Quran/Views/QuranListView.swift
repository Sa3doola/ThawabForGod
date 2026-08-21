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
                if viewModel.isSearching {
                    searchResults
                } else {
                    continueReading
                    sectionPicker
                    content
                }
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.quranTitle))
        .searchable(
            text: $viewModel.searchText,
            prompt: Text(l10n.string(.quranSearchPrompt))
        )
        // The debounce and the cancellation both live here. `.task(id:)` cancels the previous
        // run the moment the text changes, which is what turns the `Task.sleep` inside
        // `search()` into a debounce — no stored `Task`, and no search for a word half-typed.
        .task(id: viewModel.searchText) { await viewModel.search() }
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

    /// What the search turned up, or what is happening instead.
    @ViewBuilder
    private var searchResults: some View {
        switch viewModel.searchPhase {
        case .idle, .searching:
            // The hint rather than a spinner. A search of a bundled database comes back in a
            // frame or two, so a spinner would be a flash of grey and nothing else; what a
            // reader who has typed one letter actually needs is to be told what can be searched.
            InlineNotice(message: l10n.string(.quranSearchHint))

        case .results(let results):
            matches(results)

        case .empty:
            InlineNotice(message: l10n.string(.quranSearchEmpty))

        case .unavailable:
            InlineNotice(message: l10n.string(.quranUnavailable))
        }
    }

    /// The chapters first, then the verses.
    ///
    /// In that order because a chapter is the coarser answer: a reader who typed a name wants the
    /// chapter, and the handful of rows it takes to offer it sit above hundreds of verses rather
    /// than below them where nobody would scroll to find them.
    ///
    /// A `LazyVStack` rather than the plain one the lists above use — those are 114 rows of two
    /// short names, this is up to a hundred rows of Arabic paragraphs, and building them all
    /// before the first frame is exactly what the reading screen was fixed for.
    private func matches(_ results: QuranSearchResults) -> some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if !results.surahs.isEmpty {
                sectionHeading(l10n.string(.quranSearchChapters), count: nil)

                ForEach(results.surahs) { surah in
                    SurahRow(surah: surah) { open(.surah(surah.id)) }
                }
            }

            if !results.verses.isEmpty {
                sectionHeading(
                    l10n.string(.quranSearchVerses),
                    count: results.totalVerseMatches
                )

                ForEach(results.verses) { verse in
                    SearchResultRow(verse: verse, surah: viewModel.surah(verse.surahNumber)) {
                        open(verse.id)
                    }
                }
            }
        }
    }

    /// A heading over one group of results, with how many there are in total.
    ///
    /// The count is the *total*, not the number of rows below it, which is the point of showing
    /// it: the list is capped, and a reader looking at a hundred verses should be told when there
    /// are two hundred rather than left to assume they have seen them all.
    private func sectionHeading(_ title: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Text(title)

            if let count {
                Text(verbatim: "·")
                Text(l10n.string(count))
            }

            Spacer(minLength: 0)
        }
        .appFont(.footnote, weight: .semibold)
        .foregroundStyle(theme.textSecondary)
        .padding(.top, 4)
    }

    /// Opens a chapter from a result, and puts the search away behind it. See `clearSearch()`.
    ///
    /// The push comes *first*, and the order is not cosmetic. Clearing the field flips
    /// `isSearching`, which swaps this whole branch of the body back to the lists — destroying the
    /// row that is still handling the tap. Doing that before the coordinator has been told what to
    /// open leaves SwiftUI resolving a push out of a view that no longer exists, and the tab bar
    /// underneath quietly reverted to Home. Told first, the coordinator's change lands while the
    /// row is still on screen and the search is put away behind the push.
    private func open(_ reading: QuranReading) {
        coordinator.open(reading)
        viewModel.clearSearch()
    }

    /// Opens a verse from a result, at that verse. Same ordering, same reason.
    private func open(_ reference: VerseReference) {
        coordinator.open(reference)
        viewModel.clearSearch()
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
