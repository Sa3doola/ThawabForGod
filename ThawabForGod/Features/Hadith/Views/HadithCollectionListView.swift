//
//  HadithCollectionListView.swift
//  ThawabForGod
//

import SwiftUI

/// The collections the app carries, and the search field over both — the root of the Hadith tab.
///
/// Two rows, and the screen says why there are only two rather than leaving a reader to wonder
/// where the Sunan are. The reason is not a shortage of data: it is that a narration from a book
/// compiled to include weak reports needs a grading beside it, and every published grading is
/// modern scholarship this project cannot license. Saying so on the screen is the same choice
/// the adhkar make with their verification notice — the caveat belongs where the content is.
///
/// The list is built from what the corpus returned rather than from a constant, so it can never
/// offer a collection with nothing behind it.
struct HadithCollectionListView: View {
    let viewModel: HadithViewModel
    let coordinator: HadithCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var viewModel = viewModel

        return ScrollView {
            // The bookmarks card is at the top and the narrations it counts are at the bottom,
            // so tapping it has to be able to move the screen. A reader who taps a number and
            // watches nothing happen has been told the card is not a control.
            ScrollViewReader { scroll in
                VStack(spacing: 12) {
                    if viewModel.isSearching {
                        searchResults
                    } else {
                        summary(scroll)
                        continueReading
                        content
                        kept
                    }
                }
                .padding(AppSpacing.xl)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.hadithTitle))
        .searchable(
            text: $viewModel.searchText,
            prompt: Text(l10n.string(.hadithSearchPrompt))
        )
        // The debounce and the cancellation both live here. `.task(id:)` cancels the previous run
        // the moment the text changes, which is what turns the `Task.sleep` inside `search()`
        // into a debounce — no stored `Task`, and no search for a word half-typed.
        .task(id: viewModel.searchText) { await viewModel.search() }
        .task { await viewModel.loadCollections() }
        // Its own task, and re-run on every change to the stack rather than once: the reader
        // leaves this screen to read and comes back with a new position and possibly new
        // bookmarks, and nothing pushes that back up through a repository.
        .task(id: coordinator.path) { await viewModel.loadProgress() }
    }

    /// The deck and the bookmarks, as a pair across the top.
    ///
    /// Each half is absent until there is something to put in it, for the reason "continue
    /// reading" is: a card offering to review nothing is an invitation the app cannot honour. The
    /// deck's half stays visible with a count of zero *after* the deck exists, because "you are
    /// done for today" is worth saying and is different from having never started.
    @ViewBuilder
    private func summary(_ scroll: ScrollViewProxy) -> some View {
        HadithSummaryCards(
            dueCount: viewModel.dueCount,
            deckCount: viewModel.deckCount,
            bookmarkCount: viewModel.bookmarks.count,
            bookmarkedBookCount: viewModel.bookmarkedBookCount,
            review: { coordinator.memorize() },
            showBookmarks: {
                withAnimation { scroll.scrollTo(Self.bookmarksAnchor, anchor: .top) }
            }
        )
    }

    /// What the bookmarks card scrolls to. A constant rather than a literal in two places,
    /// because an anchor that does not match its target fails silently — the scroll simply does
    /// nothing, which looks exactly like a card that is not a button.
    private static let bookmarksAnchor = "hadith.bookmarks"



    // MARK: Where the reader was, and what they kept

    /// The kitab the reader was last in, offered as one row at the top.
    ///
    /// Above the collections rather than below them, because when it is there it is almost always
    /// what the reader opened the tab for. Absent entirely before they have read anything — an
    /// empty "continue" row is an invitation to nothing.
    @ViewBuilder
    private var continueReading: some View {
        if let position = viewModel.lastRead {
            HadithContinueRow(book: position.book, title: title(of: position.book)) {
                coordinator.open(position.book)
            }
        }
    }

    /// The kept narrations, newest first, under the collections.
    ///
    /// Below them rather than above: the collections are the tab's subject and are always worth
    /// showing, while bookmarks are a growing list that would push them off the screen.
    @ViewBuilder
    private var kept: some View {
        if !viewModel.bookmarks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(l10n.string(.hadithBookmarksSection))
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(Self.bookmarksAnchor)

                ForEach(viewModel.bookmarks) { kept in
                    HadithSearchResultRow(
                        hadith: kept.hadith,
                        collection: name(of: kept.hadith.collectionID)
                    ) {
                        open(kept.hadith)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    /// The kitab's Arabic title, if the divisions of that collection happen to be loaded.
    ///
    /// Best-effort on purpose. The row leads with the collection's name, which is always known,
    /// and the division's title is the detail that improves it rather than the thing it needs —
    /// loading 97 divisions on the tab's root screen to fill in one line would be a read nobody
    /// asked for.
    private func title(of book: BookReference) -> String? {
        guard case .ready(let books) = viewModel.books else { return nil }
        return books.first { $0.collectionID == book.collection && $0.number == book.number }?
            .arabicTitle
    }

    // MARK: The collections

    @ViewBuilder
    private var content: some View {
        switch viewModel.collections {
        case .loading:
            // Labelled rather than a bare spinner: VoiceOver announces something other than
            // "in progress", and the label carries the language the reader chose.
            ProgressView(l10n.string(.hadithLoading))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 48)

        case .ready(let collections):
            ForEach(collections) { collection in
                HadithCollectionRow(collection: collection) {
                    coordinator.open(collection)
                }
            }

            scopeNotice

        case .unavailable:
            InlineNotice(message: l10n.string(.hadithUnavailable))
        }
    }

    /// Why the list stops at two, and that what is here is Arabic only.
    ///
    /// Not an apology and not a roadmap — a statement of what the reader is looking at, so that
    /// an absence reads as a decision rather than as a gap someone forgot to fill.
    private var scopeNotice: some View {
        Text(l10n.string(.hadithScopeNotice))
            .appFont(.footnote)
            .foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.lg)
            .appCard(radius: AppRadius.md)
            .padding(.top, 8)
    }

    // MARK: The search

    /// What the search turned up, or what is happening instead.
    @ViewBuilder
    private var searchResults: some View {
        switch viewModel.searchPhase {
        case .idle, .searching:
            // The hint rather than a spinner. A search of a bundled database comes back in a
            // frame or two, so a spinner would be a flash of grey and nothing else; what a reader
            // who has typed one letter actually needs is to be told what can be searched.
            InlineNotice(message: l10n.string(.hadithSearchHint), tone: .informational)

        case .results(let results):
            matches(results)

        case .empty:
            InlineNotice(message: l10n.string(.hadithSearchEmpty), tone: .informational)

        case .unavailable:
            InlineNotice(message: l10n.string(.hadithUnavailable))
        }
    }

    /// The matching narrations, under a count of how many there are in total.
    ///
    /// A `LazyVStack` rather than the plain one the collections use — those are two rows of two
    /// short names, these are up to fifty rows of Arabic paragraphs, and building them all before
    /// the first frame is exactly what the reading screen was fixed for.
    private func matches(_ results: HadithSearchResults) -> some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            heading(results)

            ForEach(results.hadiths) { hadith in
                HadithSearchResultRow(
                    hadith: hadith,
                    collection: name(of: hadith.collectionID)
                ) {
                    open(hadith)
                }
            }
        }
    }

    /// `Narrations: 50 of 912`, or just the count when nothing was cut off.
    ///
    /// The total matters more here than it does in the Quran: a common word in fifteen thousand
    /// narrations of isnad and matn matches a great many rows, and a reader who is shown fifty
    /// without being told there are nine hundred will read the fifty as the answer.
    @ViewBuilder
    private func heading(_ results: HadithSearchResults) -> some View {
        HStack(spacing: 4) {
            Text(l10n.string(.hadithSearchResults))

            if results.total > results.hadiths.count {
                Text(l10n.string(results.hadiths.count))
                Text(l10n.string(.hadithSearchOf))
            }

            Text(l10n.string(results.total))
        }
        .appFont(.footnote, weight: .semibold)
        .foregroundStyle(theme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Opens the kitab a result sits in, scrolled to it, and puts the search away behind the push.
    ///
    /// The collection comes from the list this screen already loaded — which is always loaded,
    /// because this is the screen the search field is on.
    private func open(_ hadith: Hadith) {
        guard case .ready(let collections) = viewModel.collections,
              let collection = collections.first(where: { $0.id == hadith.collectionID })
        else { return }

        coordinator.open(hadith, in: collection)
        viewModel.clearSearch()
    }

    /// The collection's Arabic name, for the row's label. Empty if the list is somehow not loaded,
    /// which leaves the row showing its number alone rather than a placeholder.
    private func name(of collectionID: String) -> String {
        guard case .ready(let collections) = viewModel.collections else { return "" }
        return collections.first { $0.id == collectionID }?.arabicName ?? ""
    }
}

/// Outside the `#Preview` macro on purpose, for the reason `previewQuranViewModel()` documents:
/// `HadithProgressRepository`'s initialiser is generated by `@ModelActor`, and macro-generated
/// members are not visible from inside another macro's expansion.
@MainActor
func previewHadithViewModel() -> HadithViewModel {
    let persistence = try! PersistenceController(inMemory: true)
    let corpus = HadithRepository(database: CorpusDatabase(name: "hadith"))

    return HadithViewModel(
        useCase: GetHadithUseCase(repository: corpus),
        progress: HadithProgressUseCase(
            progress: HadithProgressRepository(modelContainer: persistence.container),
            corpus: corpus
        ),
        memorize: MemorizeHadithUseCase(
            memorization: HadithMemorizationRepository(modelContainer: persistence.container),
            corpus: corpus
        ),
        clock: SystemClockService()
    )
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        HadithCollectionListView(
            viewModel: previewHadithViewModel(),
            coordinator: HadithCoordinator()
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
