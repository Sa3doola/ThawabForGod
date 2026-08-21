//
//  QuranViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives both Quran screens: the list of chapters and parts, and the text of the one being read.
///
/// One type for two screens, the same shape as `AdhkarViewModel` — which is what lets the
/// reading screen be handed a view model rather than build one out of a use case it would have
/// to be given anyway. It owns no text of its own: every verse comes from the corpus through
/// `GetQuranUseCase`, which is what lets this be tested against a handful of stub values instead
/// of a database.
@Observable
@MainActor
final class QuranViewModel {

    /// Which list the segmented control is showing.
    ///
    /// Bookmarks are a third *segment* rather than a screen of their own: choosing where to start
    /// reading is one act whether the reader picks a chapter, a part, or something they kept, and
    /// a saved verse is no more a separate destination than a chapter is.
    enum Section: Hashable, CaseIterable {
        case surahs
        case juz
        case bookmarks
    }

    /// What the list screen has to show.
    enum ListPhase: Equatable {
        case loading
        case ready(surahs: [Surah], juz: [Juz])
        /// The corpus could not be read — a packaging fault, not something the reader did.
        case unavailable
    }

    /// What the search field has turned up.
    ///
    /// `.idle` is not "nothing found" — it is the state before there is anything to find, when
    /// the field is empty or holds only punctuation. The two have to be told apart or an empty
    /// field would sit under "no results".
    enum SearchPhase: Equatable {
        case idle
        case searching
        case results(QuranSearchResults)
        case empty
        /// The corpus could not be read. Its own case rather than `.empty`, because "there is no
        /// such verse" and "the search did not run" are different things to tell a reader.
        case unavailable
    }

    /// What the reading screen has to show.
    enum ReadingPhase: Equatable {
        case loading
        case ready(Reading)
        case unavailable
    }

    /// A loaded span of text, and what is needed to draw its headings.
    struct Reading: Equatable {

        /// The verses, in reading order.
        let verses: [Verse]

        /// The chapters those verses fall in, by number. Held because a part crosses chapter
        /// boundaries and the reader has to be told when it does; looking that up per verse
        /// against the repository would be a query inside a scroll.
        let surahs: [Int: Surah]

        /// The chapters in the order they appear — for a single chapter, one.
        var surahOrder: [Int] {
            var seen: Set<Int> = []
            return verses.map(\.surahNumber).filter { seen.insert($0).inserted }
        }

        /// The verses of one chapter *within this span*, which for a part is not every verse
        /// that chapter has.
        func verses(inSurah number: Int) -> [Verse] {
            verses.filter { $0.surahNumber == number }
        }

        /// One row of the reading screen, in the order it is drawn.
        ///
        /// The span is flattened to a single list rather than left as chapters-containing-verses
        /// because a `LazyVStack` is only lazy in its *direct* children. Nested, a whole chapter
        /// was one child — so all 286 verses of Al-Baqara were built before the first frame, every
        /// `onAppear` fired at once, and scrolling fired none. That is not only slow: it is what
        /// made the last-read position stick at the first verse for good, since the appearance
        /// that set it was the only one that ever happened.
        enum Item: Identifiable, Hashable {
            case heading(Int)
            case bismillah(Int)
            case verse(Verse)

            var id: String {
                switch self {
                case .heading(let surah): "heading-\(surah)"
                case .bismillah(let surah): "bismillah-\(surah)"
                case .verse(let verse): "verse-\(verse.id)"
                }
            }
        }

        /// The whole span as one flat list — headings and basmalas in place, verses in order.
        var items: [Item] {
            var items: [Item] = []
            let order = surahOrder
            // Named only when the span covers more than one chapter: reading a single chapter,
            // the navigation title already says which, and a heading under it would be the name
            // twice on one screen.
            let namesChapters = order.count > 1

            for number in order {
                if namesChapters, surahs[number] != nil {
                    items.append(.heading(number))
                }
                if showsBismillah(forSurah: number) {
                    items.append(.bismillah(number))
                }
                items.append(contentsOf: verses(inSurah: number).map(Item.verse))
            }
            return items
        }

        /// Whether the chapter's basmala heading belongs above it here.
        ///
        /// Only where this span actually contains that chapter's first verse. Juz 2 opens at
        /// 2:142, and printing the heading that belongs above 2:1 would tell the reader they are
        /// at the start of Al-Baqara when they are arriving in the middle of it.
        func showsBismillah(forSurah number: Int) -> Bool {
            guard surahs[number]?.bismillah != nil else { return false }
            return verses(inSurah: number).first?.number == 1
        }
    }

    // MARK: State

    private(set) var listPhase: ListPhase = .loading
    private(set) var readingPhase: ReadingPhase = .loading

    /// Settable from the view because a `Picker` needs a two-way binding; routing a segment
    /// change through a method would buy nothing.
    var section: Section = .surahs

    /// The kept verses, newest first, and the same set keyed for lookup.
    ///
    /// Both, because the two screens ask different questions of the same data: the bookmarks
    /// segment wants them in order, and every `VerseRow` in a chapter wants to know whether *it*
    /// is one — which against an array would be a linear scan per verse, 286 of them in
    /// Al-Baqara alone.
    private(set) var bookmarks: [QuranBookmark] = []
    private(set) var bookmarkedVerses: Set<VerseReference> = []

    /// Where the reader left off, or `nil` before they have read anything.
    private(set) var lastRead: ReadingPosition?

    /// What is in the search field. Settable from the view, like `section`, because
    /// `.searchable` needs a binding.
    var searchText: String = ""

    private(set) var searchPhase: SearchPhase = .idle

    /// Whether the screen is showing results rather than its lists.
    ///
    /// Derived from the text rather than from `\.isSearching`: that environment value is only
    /// readable *inside* the searchable view's own subtree, and this is read by the view that
    /// applies the modifier. It also has to agree with `searchPhase`, which is driven by the
    /// same text.
    var isSearching: Bool { !QuranSearchQuery(searchText).isEmpty }

    @ObservationIgnored private let useCase: GetQuranUseCase
    @ObservationIgnored private let progress: QuranProgressUseCase

    /// Where Home's recent-activity chip is fed from. Optional because it is a convenience on a
    /// different screen: a reader whose activity is not being recorded reads exactly the same.
    @ObservationIgnored private let activity: ActivityRecorder?

    /// The last verse to come into view, held *outside* observation.
    ///
    /// Every visible `VerseRow` reports itself as it appears, which on a fast scroll is many
    /// writes a second. `@ObservationIgnored` is what keeps that from being many redraws a
    /// second: nothing reads this during a view update — it is only ever consumed by
    /// `saveReadingPosition()` on the way out.
    @ObservationIgnored private var verseInView: VerseReference?

    /// The position write that leaving the reading screen started, if it has not finished.
    ///
    /// Held because the two halves of "go back" race: popping the reader fires its `onDisappear`,
    /// and the list underneath re-runs `loadProgress()` at the same moment. Without this, the
    /// re-read usually won — and the reader watched "continue reading" go on naming the verse
    /// they opened at rather than the one they got to. Seen on device, not reasoned about.
    @ObservationIgnored private var pendingPositionWrite: Task<Void, Never>?

    init(
        useCase: GetQuranUseCase,
        progress: QuranProgressUseCase,
        activity: ActivityRecorder? = nil
    ) {
        self.useCase = useCase
        self.progress = progress
        self.activity = activity
    }

    // MARK: Derived

    var surahs: [Surah] {
        guard case .ready(let surahs, _) = listPhase else { return [] }
        return surahs
    }

    var juz: [Juz] {
        guard case .ready(_, let juz) = listPhase else { return [] }
        return juz
    }

    /// One chapter by number, for the rows that name a verse's chapter without holding one.
    ///
    /// A linear scan over 114 rows, which is cheap and stays honest: a dictionary cached beside
    /// the array would be a second copy of the same data to keep in step for no measurable gain
    /// at this size.
    func surah(_ number: Int) -> Surah? {
        surahs.first { $0.id == number }
    }

    // MARK: Loading

    /// Loads both lists.
    ///
    /// Together rather than one per segment: they come out of the same file, they are 144 small
    /// rows between them, and loading on demand would put a spinner in front of a reader who
    /// only flicked a segmented control.
    ///
    /// Driven from the view's `.task`, so SwiftUI owns the lifetime — there is no stored `Task`
    /// here and nothing to cancel by hand.
    func loadList() async {
        listPhase = .loading

        do {
            // Concurrently, because they are two independent reads and the second has no reason
            // to wait on the first.
            async let surahs = useCase.surahs()
            async let juz = useCase.juzList()

            let loaded = try await (surahs: surahs, juz: juz)
            guard !Task.isCancelled else { return }
            listPhase = .ready(surahs: loaded.surahs, juz: loaded.juz)
        } catch {
            guard !Task.isCancelled else { return }
            listPhase = .unavailable
        }
    }

    /// Loads the verses of a chapter or a part, with the chapters needed to head them.
    func load(_ reading: QuranReading) async {
        readingPhase = .loading
        clearVerseInView()

        do {
            async let chapters = useCase.surahs()
            async let verses = fetchVerses(for: reading)

            let loaded = try await (chapters: chapters, verses: verses)
            guard !Task.isCancelled else { return }

            // Nothing coming back is a failure rather than an empty screen: every chapter and
            // every part of the mushaf has verses, so an empty result means the corpus is not
            // what it claims to be.
            guard !loaded.verses.isEmpty else {
                readingPhase = .unavailable
                return
            }

            readingPhase = .ready(
                Reading(
                    verses: loaded.verses,
                    surahs: Dictionary(uniqueKeysWithValues: loaded.chapters.map { ($0.id, $0) })
                )
            )
        } catch {
            guard !Task.isCancelled else { return }
            readingPhase = .unavailable
        }
    }

    // MARK: Search

    /// How long the field has to stand still before the corpus is asked.
    ///
    /// Short enough that a reader who has stopped typing does not notice it, long enough that
    /// typing a word is one search rather than seven. It is a constant rather than a setting
    /// because it is a property of how fast people type, not of what anyone prefers.
    private static let debounce = Duration.milliseconds(200)

    /// Searches for whatever is in `searchText`.
    ///
    /// Driven from the view's `.task(id: viewModel.searchText)`, which is the whole cancellation
    /// story: SwiftUI cancels the previous run the moment the text changes, so the `Task.sleep`
    /// below throws and that keystroke's search never reaches the corpus. There is no stored
    /// `Task` here and nothing to cancel by hand — the debounce *is* the sleep, and the id is
    /// what makes it one.
    func search() async {
        let query = QuranSearchQuery(searchText)

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

    /// Empties the field, which puts the lists back.
    ///
    /// Called when a result is opened: coming back from a verse to the search that found it is
    /// rarely what is wanted, and a field left full would hide the chapter list behind results
    /// the reader is done with.
    func clearSearch() {
        searchText = ""
        searchPhase = .idle
    }

    // MARK: The reader's own marks

    /// Loads the bookmarks and the last-read position.
    ///
    /// Its own method rather than part of `loadList()`, and driven from the same `.task`: these
    /// come out of a different store than the lists do, and a failure to read the user's marks
    /// should leave the chapters on screen rather than replacing them with "unavailable". So a
    /// throw here empties the marks and says nothing — the corpus is what the screen is *for*.
    func loadProgress() async {
        // Anything still being written has to land before this reads, or it reads the value it
        // is about to be told is stale. See `pendingPositionWrite`.
        await pendingPositionWrite?.value

        do {
            async let bookmarks = progress.bookmarks()
            async let position = progress.lastRead()

            let loaded = try await (bookmarks: bookmarks, position: position)
            guard !Task.isCancelled else { return }

            self.bookmarks = loaded.bookmarks
            self.bookmarkedVerses = Set(loaded.bookmarks.map(\.reference))
            self.lastRead = loaded.position
        } catch {
            guard !Task.isCancelled else { return }
            bookmarks = []
            bookmarkedVerses = []
            lastRead = nil
        }
    }

    /// Keeps or forgets a verse, moving the on-screen state first.
    ///
    /// Optimistic on purpose: the tap is on a verse the reader is looking at, and a bookmark that
    /// filled in only once SwiftData had saved would lag behind the finger. The set is put back
    /// if the write fails, so the screen cannot end up claiming something was kept when it was
    /// not.
    func setBookmark(_ isBookmarked: Bool, for reference: VerseReference) async {
        let previous = bookmarkedVerses

        if isBookmarked {
            bookmarkedVerses.insert(reference)
        } else {
            bookmarkedVerses.remove(reference)
        }

        do {
            try await progress.setBookmark(isBookmarked, for: reference)
            // Re-read rather than splicing the array by hand: the store owns the order, and a
            // repository has no `@Query` to push the change back on its own.
            bookmarks = try await progress.bookmarks()
            bookmarkedVerses = Set(bookmarks.map(\.reference))
        } catch {
            bookmarkedVerses = previous
        }
    }

    func isBookmarked(_ reference: VerseReference) -> Bool {
        bookmarkedVerses.contains(reference)
    }

    /// Called by every `VerseRow` as it scrolls into view. Cheap by construction — see
    /// `verseInView`.
    func noteVerseInView(_ reference: VerseReference) {
        verseInView = reference
    }

    /// Forgets the verse in view, so leaving a chapter cannot write a position belonging to the
    /// one before it. Called when a new span starts loading.
    private func clearVerseInView() {
        verseInView = nil
    }

    /// Persists the last verse that came into view.
    ///
    /// Written when the reader leaves the reading screen rather than as they scroll, because a
    /// write per verse boundary is a SwiftData save per verse boundary. What it records is the
    /// last verse to *appear*, which going down the page is the furthest they reached — the
    /// honest answer to "where was I" — and going back up is the verse they scrolled to.
    ///
    /// Not `async`: the caller is an `onDisappear`, which cannot await anything. The work is
    /// parked on `pendingPositionWrite` instead, and `loadProgress()` waits on it — which is what
    /// keeps the list from re-reading the store mid-write.
    func saveReadingPosition() {
        guard let verse = verseInView else { return }

        // Home's recent-activity chip, recorded from the same moment and the same verse — the
        // two answer the same question and must not be able to disagree. Flushed rather than
        // left to the debounce, because this *is* the exit the debounce was waiting for.
        let verseCount = surah(verse.surah)?.verseCount
        let recorder = activity

        let previous = pendingPositionWrite
        pendingPositionWrite = Task { [progress] in
            // Ordered behind whatever was already in flight, so two quick exits cannot land
            // out of sequence and leave the older verse stored.
            await previous?.value

            if let recorder, let verseCount {
                recorder.record(.quran(verse, of: verseCount, at: Date()))
                await recorder.flush()
            }

            do {
                try await progress.recordLastRead(verse)
                self.lastRead = try await progress.lastRead()
            } catch {
                // Losing a position is not worth telling the reader about: the text is
                // unaffected, and the next thing they read overwrites it anyway.
            }
        }
    }

    private func fetchVerses(for reading: QuranReading) async throws -> [Verse] {
        switch reading {
        case .surah(let number):
            try await useCase.verses(inSurah: number)
        case .juz(let number):
            try await useCase.verses(inJuz: number)
        }
    }
}
