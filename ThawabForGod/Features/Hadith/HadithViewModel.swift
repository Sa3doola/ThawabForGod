//
//  HadithViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives all three hadith screens: the collections, one collection's divisions, and one
/// division's narrations.
///
/// One view model for the stack rather than three, because the three screens are one journey
/// into one corpus and splitting them would mean three objects, three container accessors and
/// three copies of the same loading shape. The Quran's tab is arranged the same way.
///
/// Each screen's state is a separate `Phase`, and each is a single slot: opening a second
/// collection replaces the divisions rather than accumulating them. That is the right trade for
/// a stack the reader walks *down* — there is only ever one collection and one kitab open — and
/// it means the memory this holds is bounded by the largest kitab rather than by how long the
/// tab has been open.
@Observable
@MainActor
final class HadithViewModel {

    /// What a screen has to show, whatever it is showing.
    ///
    /// Generic rather than three near-identical enums, which is a departure from the other
    /// content view models and earns it here: the three screens differ in what they load and not
    /// at all in how loading goes, so three copies of `loading`/`ready`/`unavailable` would be
    /// three places to keep in step.
    /// `nonisolated` because a nested type inherits the module's `MainActor` default, and a
    /// main-actor-isolated `Equatable` conformance cannot satisfy a `Sendable` type parameter's
    /// requirement. The same reason `Reading` below carries it: neither holds anything the main
    /// actor needs to protect.
    nonisolated enum Phase<Value: Equatable & Sendable>: Equatable, Sendable {
        case loading
        case ready(Value)
        /// The corpus could not be read — a packaging fault, not something the user did.
        case unavailable
    }

    /// A kitab and its narrations, which the reading screen needs together.
    ///
    /// One value rather than two phases, so the screen cannot be in the state where it has the
    /// narrations and not the title to put above them.
    nonisolated struct Reading: Equatable, Sendable {
        let book: HadithBook
        let hadiths: [Hadith]

        /// The kitab either side of this one, for the footer that pages between them. `nil` at
        /// the two ends of a collection, where the button is absent rather than disabled — a
        /// control that can never do anything is not a control.
        ///
        /// References rather than whole books: the footer names the *direction*, and the title
        /// it would need is the one thing this screen will load anyway on arriving.
        let previous: BookReference?
        let next: BookReference?
    }

    /// What the search field has turned up, or what is happening instead.
    ///
    /// Its own enum rather than a `Phase`, because searching has two states loading does not:
    /// nothing typed yet, and typed but matching nothing. Folding either into `.loading` would
    /// make the screen say "loading" when it is finished and has an answer.
    nonisolated enum SearchPhase: Equatable, Sendable {
        /// Nothing to search for — the field is empty, or holds only punctuation.
        case idle
        case searching
        case results(HadithSearchResults)
        /// Searched, and the corpus has nothing. Distinct from `.idle`, which has not looked.
        case empty
        case unavailable
    }

    // MARK: State

    private(set) var collections: Phase<[HadithCollection]> = .loading
    private(set) var books: Phase<[HadithBook]> = .loading
    private(set) var reading: Phase<Reading> = .loading

    /// What has been typed into the search field.
    ///
    /// Settable from the view, unlike the rest of this type's state, because `.searchable` needs
    /// a two-way binding and routing every keystroke through a method would buy nothing.
    var searchText: String = ""

    private(set) var searchPhase: SearchPhase = .idle

    /// Whether a search is standing in front of the collections.
    ///
    /// Derived from the text rather than from `\.isSearching`: that environment value is only
    /// available *below* the view that applies the modifier. It also has to agree with
    /// `searchPhase`, which is driven by the folded query — so a field holding only punctuation
    /// is not "searching", and the collections stay where they are.
    var isSearching: Bool { !ArabicSearchQuery(searchText).isEmpty }

    /// The kept narrations, joined back to their text.
    ///
    /// Loaded beside the collections rather than behind a tab of its own: two collections make a
    /// short screen, and what a reader actually returns to this tab for is usually something they
    /// kept. Empty until `loadProgress()` has run, which is not the same as "no bookmarks" — the
    /// screen draws the section only when there is one.
    private(set) var bookmarks: [KeptHadith] = []

    /// The identities of those bookmarks, which is what the reading screen asks about.
    ///
    /// Kept as a `Set` because the reading screen asks once per narration on screen and Muslim's
    /// Book of Faith is 436 of them — a linear scan per row is the kind of cost that only shows
    /// up on the longest kitab, which is exactly where it must not.
    private(set) var bookmarkedIDs: Set<HadithID> = []

    /// Which kitab the reader left off in, or `nil` before they have read anything.
    private(set) var lastRead: HadithReadingPosition?

    /// The identities of the narrations in the review deck, for the reading screen's second mark.
    ///
    /// A `Set` for the reason `bookmarkedIDs` is one: the reading screen asks per narration on
    /// screen, and Muslim's Book of Faith is 436 of them.
    private(set) var memorizingIDs: Set<HadithID> = []

    /// How many cards are due now. Drives the one row that offers a review session, and is `0`
    /// both when nothing is due and when the deck is empty — the row says which.
    private(set) var dueCount = 0

    /// Whether the deck has anything in it at all, due or not.
    private(set) var hasDeck = false

    /// How many narrations are in the deck. The second line of the memorize card — what is
    /// *committed to*, beside what is due today, because a reader with nothing due has still
    /// built something and the card should say so.
    private(set) var deckCount = 0

    @ObservationIgnored private let useCase: GetHadithUseCase
    @ObservationIgnored private let progress: HadithProgressUseCase
    @ObservationIgnored private let memorize: MemorizeHadithUseCase
    @ObservationIgnored private let clock: any ClockService

    /// Parked writes of the reading position, awaited before the list reloads.
    ///
    /// **The Quran's slice learned this on device and it applies here unchanged.** Popping the
    /// reading screen fires its `onDisappear` while the list underneath re-runs `loadProgress()`,
    /// so a position written without this handle races the read that is meant to show it — and
    /// "continue reading" goes on naming the kitab the reader opened *before* this one.
    @ObservationIgnored private var pendingWrite: Task<Void, Never>?

    init(
        useCase: GetHadithUseCase,
        progress: HadithProgressUseCase,
        memorize: MemorizeHadithUseCase,
        clock: any ClockService
    ) {
        self.useCase = useCase
        self.progress = progress
        self.memorize = memorize
        self.clock = clock
    }

    // MARK: Loading

    func loadCollections() async {
        collections = .loading

        do {
            collections = .ready(try await useCase.collections())
        } catch {
            collections = .unavailable
        }
    }

    func loadBooks(in collectionID: String) async {
        books = .loading

        do {
            books = .ready(try await useCase.books(inCollection: collectionID))
        } catch {
            books = .unavailable
        }
    }

    /// The narrations of a kitab, with the kitab itself.
    ///
    /// The division is fetched rather than taken from `books`, even when the reader arrived by
    /// tapping a row in that list. It costs one indexed lookup and it means this screen has no
    /// opinion about what happened before it — which is what lets a bookmark or a search result
    /// open it without the list ever having been drawn.
    ///
    /// The collection's divisions are read for the same reason, and that is what the footer's two
    /// buttons are derived from. **Neighbours are positions in that list, never `number ± 1`:**
    /// the kitab numbers are the published collections' own and are not guaranteed to run without
    /// a gap, so arithmetic on them would eventually page to a division that does not exist and
    /// leave the reader on an empty screen.
    func loadReading(_ reference: BookReference) async {
        reading = .loading

        do {
            guard let book = try await useCase.book(reference) else {
                // A reference to a division the corpus does not have. There is no reading to
                // show and nothing the reader can do about it, which is `unavailable` exactly.
                reading = .unavailable
                return
            }

            let hadiths = try await useCase.hadiths(inBook: reference)
            let siblings = try await useCase.books(inCollection: reference.collection)
            let index = siblings.firstIndex { $0.number == reference.number }

            reading = .ready(
                Reading(
                    book: book,
                    hadiths: hadiths,
                    previous: index.flatMap { $0 > 0 ? siblings[$0 - 1].id : nil },
                    next: index.flatMap { $0 < siblings.count - 1 ? siblings[$0 + 1].id : nil }
                )
            )
        } catch {
            reading = .unavailable
        }
    }

    // MARK: The reader's own marks

    /// Loads the bookmarks and the last-read position.
    ///
    /// Awaits any parked position write first, so the read cannot overtake it. See
    /// `pendingWrite` — this is the whole reason that handle exists.
    func loadProgress() async {
        await pendingWrite?.value
        pendingWrite = nil

        do {
            let kept = try await progress.bookmarks()
            bookmarks = kept
            bookmarkedIDs = Set(kept.map(\.id))
            lastRead = try await progress.lastRead()

            let deck = try await memorize.deck()
            memorizingIDs = Set(deck.map(\.id))
            hasDeck = !deck.isEmpty
            deckCount = deck.count
            dueCount = try await memorize.dueCount(on: clock.now)
        } catch {
            // A store that will not read is not something the reader can act on, and it must not
            // cost them the collections. The sections simply do not appear.
            bookmarks = []
            bookmarkedIDs = []
            lastRead = nil
            memorizingIDs = []
            hasDeck = false
            deckCount = 0
            dueCount = 0
        }
    }

    /// How many distinct kitab the kept narrations are spread across — the bookmarks card's
    /// second line.
    ///
    /// Counted from what is already loaded rather than asked of the store: `bookmarks` is in
    /// memory and a `COUNT(DISTINCT …)` would be a second read for a number the app is holding
    /// the inputs to.
    var bookmarkedBookCount: Int {
        Set(bookmarks.map { BookReference(collection: $0.hadith.collectionID, number: $0.hadith.bookNumber) })
            .count
    }

    /// Whether a narration is in the review deck. Answered from memory, per narration on screen.
    func isMemorizing(_ hadith: Hadith) -> Bool {
        memorizingIDs.contains(hadith.id)
    }

    /// Puts a narration in the review deck, or takes it out.
    ///
    /// The set is updated before the write for the reason `toggleBookmark(_:)` does it: so the
    /// mark changes under the reader's finger rather than a frame later.
    func toggleMemorizing(_ hadith: Hadith) async {
        if memorizingIDs.contains(hadith.id) {
            memorizingIDs.remove(hadith.id)
        } else {
            memorizingIDs.insert(hadith.id)
        }

        do {
            try await memorize.toggle(hadith, on: clock.now)

            let deck = try await memorize.deck()
            memorizingIDs = Set(deck.map(\.id))
            hasDeck = !deck.isEmpty
            deckCount = deck.count
            dueCount = try await memorize.dueCount(on: clock.now)
        } catch {
            // Put the mark back where the store says it is, rather than leaving it showing a
            // state nothing was written for.
            memorizingIDs = memorizingIDs.subtracting([hadith.id])
        }
    }

    /// Whether a narration is kept. Answered from memory, per narration on screen.
    func isBookmarked(_ hadith: Hadith) -> Bool {
        bookmarkedIDs.contains(hadith.id)
    }

    /// Keeps a narration, or forgets it if it was kept.
    ///
    /// The set is updated before the write rather than after it, so the button changes under the
    /// reader's finger instead of a frame later. The reload afterwards is what makes the
    /// *bookmarks list* right; this is what makes the button right.
    func toggleBookmark(_ hadith: Hadith) async {
        if bookmarkedIDs.contains(hadith.id) {
            bookmarkedIDs.remove(hadith.id)
        } else {
            bookmarkedIDs.insert(hadith.id)
        }

        do {
            try await progress.toggleBookmark(hadith)
            let kept = try await progress.bookmarks()
            bookmarks = kept
            bookmarkedIDs = Set(kept.map(\.id))
        } catch {
            // Put the button back where the store says it is, rather than leaving it showing a
            // state nothing was written for.
            bookmarkedIDs = Set(bookmarks.map(\.id))
        }
    }

    /// Records which kitab the reader is in, without making them wait for it.
    ///
    /// Parked on `pendingWrite` rather than awaited: this is called as the reading screen goes
    /// away, and the screen underneath is already reloading. `loadProgress()` awaits the handle,
    /// which is what stops the read from beating the write.
    func recordLastRead(_ book: BookReference) {
        pendingWrite = Task { [progress] in
            try? await progress.recordLastRead(book)
        }
    }

    // MARK: Search

    /// How long the field has to stand still before the corpus is asked.
    ///
    /// Short enough that a reader who has stopped typing does not notice it, long enough that
    /// typing a word is one search rather than seven. A constant rather than a setting because it
    /// is a property of how fast people type, not of what anyone prefers.
    private static let debounce = Duration.milliseconds(200)

    /// Searches for whatever is in `searchText`.
    ///
    /// Driven from the view's `.task(id: viewModel.searchText)`, which is the whole cancellation
    /// story: SwiftUI cancels the previous run the moment the text changes, so the `Task.sleep`
    /// below throws and that keystroke's search never reaches the corpus. There is no stored
    /// `Task` here and nothing to cancel by hand — the debounce *is* the sleep, and the id is
    /// what makes it one.
    func search() async {
        let query = ArabicSearchQuery(searchText)

        guard !query.isEmpty else {
            searchPhase = .idle
            return
        }

        do {
            try await Task.sleep(for: Self.debounce)
        } catch {
            // Cancelled: a newer query is already on its way, and this one must not touch the
            // phase on the way out or it would overwrite results that are still arriving.
            return
        }

        // Only now, so that a reader typing a word watches the previous results sit still rather
        // than watching a spinner replace them on every letter.
        searchPhase = .searching

        do {
            let results = try await useCase.search(query)
            guard !Task.isCancelled else { return }
            searchPhase = results.isEmpty ? .empty : .results(results)
        } catch {
            guard !Task.isCancelled else { return }
            searchPhase = .unavailable
        }
    }

    /// Empties the field, which puts the collections back.
    ///
    /// Called when a result is opened: coming back from a narration to the search that found it
    /// is rarely what is wanted, and a field left full would hide the collections behind results
    /// the reader is done with.
    func clearSearch() {
        searchText = ""
        searchPhase = .idle
    }
}
