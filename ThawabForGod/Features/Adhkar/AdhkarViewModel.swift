//
//  AdhkarViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives both adhkar screens: the browse list of 132 chapters, and the one being read.
///
/// It owns no text of its own — every word of every dhikr comes from the corpus through
/// `GetAdhkarUseCase`, which is what lets this type be tested against a handful of stub values
/// instead of a database.
///
/// **The repeat counters are deliberately not persisted.** Tapping through a dhikr is a reading
/// session, not a record: it belongs to the screen the reader has open, and it goes when they
/// leave. Saving progress across launches is a real feature with real questions behind it — does
/// it reset at dawn, does it sync, what happens on the day someone reads the morning adhkar at
/// midnight — and those belong to the Memorize module, not to a tap counter.
@Observable
@MainActor
final class AdhkarViewModel {

    /// What the browse screen has to show.
    enum CategoriesPhase: Equatable {
        case loading
        case ready([AdhkarCategory])
        /// The corpus could not be read — a packaging fault, not something the reader did.
        case unavailable
    }

    /// What the reading screen has to show.
    enum ReadingPhase: Equatable {
        case loading
        case ready([Dhikr])
        case unavailable
    }

    /// One heading's worth of the browse list.
    struct Section: Identifiable, Equatable {
        let group: AdhkarGroup
        let categories: [AdhkarCategory]

        var id: AdhkarGroup.ID { group.id }
    }

    // MARK: State

    private(set) var categoriesPhase: CategoriesPhase = .loading
    private(set) var readingPhase: ReadingPhase = .loading

    /// What the reader has typed into the browse screen's search field.
    ///
    /// Stored here rather than in the view so the filtering can be tested without a screen, and
    /// so it survives the list being rebuilt. Not debounced: the whole search is a pass over 132
    /// short strings already in memory, which is nothing next to the keystroke that triggered it.
    var searchText: String = ""

    /// The chapter currently loaded, which is what titles the reading screen and how a re-read is
    /// told apart from a move to another chapter. Only the second clears the counters.
    private(set) var category: AdhkarCategory?

    /// How many times each dhikr has been said, keyed by id and scoped to `category`.
    private var repeatCounts: [Dhikr.ID: Int] = [:]

    /// The point size the adhkar are set at.
    ///
    /// Its own preference rather than the Quran's `readerTextSize` — see `SettingsKey` for why —
    /// and **written only when the reader moves the control**, which is the rule the whole
    /// settings layer is built on: a stored preference outranks the device forever, so persisting
    /// a computed default converts "no opinion" into a choice that cannot be undone.
    private(set) var textSize: Double

    @ObservationIgnored private let useCase: GetAdhkarUseCase

    /// Where Home's recent-activity chip is fed from. Optional: reading the adhkar is unchanged
    /// without it.
    @ObservationIgnored private let activity: ActivityRecorder?

    @ObservationIgnored private let settingsStore: any SettingsStore

    /// The folded haystack for each chapter, built once when the list loads.
    ///
    /// Cached rather than folded per keystroke: 132 chapters × two titles is a few thousand
    /// characters to normalise, and doing it on every character typed would be the one part of
    /// this search that could be felt.
    @ObservationIgnored private var searchIndex: [AdhkarCategory.ID: [String]] = [:]

    init(
        useCase: GetAdhkarUseCase,
        settingsStore: any SettingsStore = InMemorySettingsStore(),
        activity: ActivityRecorder? = nil
    ) {
        self.useCase = useCase
        self.settingsStore = settingsStore
        self.activity = activity
        // Clamped through `ReaderTypography`, which is the one place the bounds are stated — a
        // value hand-edited into the store, or written by a build with a different range, should
        // produce readable text rather than a page of one glyph.
        self.textSize = ReaderTypography(
            textSize: settingsStore.double(for: .adhkarTextSize) ?? ReaderTypography.fallback.textSize,
            lineSpacing: ReaderTypography.fallback.lineSpacing
        ).textSize
    }

    /// Stores what was asked for and keeps what was allowed.
    func setTextSize(_ value: Double) {
        let clamped = ReaderTypography(
            textSize: value,
            lineSpacing: ReaderTypography.fallback.lineSpacing
        ).textSize

        guard clamped != textSize else { return }
        textSize = clamped
        settingsStore.set(clamped, for: .adhkarTextSize)
    }

    var canEnlargeText: Bool { textSize < ReaderTypography.textSizeRange.upperBound }
    var canShrinkText: Bool { textSize > ReaderTypography.textSizeRange.lowerBound }

    func enlargeText() { setTextSize(textSize + ReaderTypography.textSizeStep) }
    func shrinkText() { setTextSize(textSize - ReaderTypography.textSizeStep) }

    // MARK: Loading

    /// Loads the chapters the corpus actually holds.
    ///
    /// Driven from the list's `.task`, so SwiftUI owns its lifetime — there is no stored `Task`
    /// here and nothing to cancel by hand.
    func loadCategories() async {
        // Not reset to `.loading` when there is already a list: this runs again every time the
        // browse screen appears, and blanking a list that is about to be replaced by itself is a
        // flash of nothing for no reason.
        if case .ready = categoriesPhase {} else { categoriesPhase = .loading }

        do {
            let categories = try await useCase.categories()
            guard !Task.isCancelled else { return }

            searchIndex = Dictionary(
                uniqueKeysWithValues: categories.map { ($0.id, Self.haystack(for: $0)) }
            )
            categoriesPhase = .ready(categories)
        } catch {
            guard !Task.isCancelled else { return }
            categoriesPhase = .unavailable
        }
    }

    /// Loads one chapter and its adhkar, by slug.
    ///
    /// **By slug rather than by value**, because the reading screen is reachable from a deep link
    /// and a saved shortcut carries a string, not an `AdhkarCategory`. Resolving it here means the
    /// screen has one way in rather than two, and a slug this corpus has never heard of is an
    /// `.unavailable` rather than a crash.
    func load(categoryID: String) async {
        // A different chapter is a different reading session; re-running the task for the same
        // one — which a language change does — is the same session, and the taps stand.
        if categoryID != category?.id {
            repeatCounts.removeAll()
            category = nil
            readingPhase = .loading
        }

        do {
            guard let category = try await useCase.category(id: categoryID) else {
                guard !Task.isCancelled else { return }
                readingPhase = .unavailable
                return
            }

            let adhkar = try await useCase.adhkar(in: category)
            // The task driving this is cancelled when the screen goes away. Without this check a
            // slower, older result could land on top of a newer one.
            guard !Task.isCancelled else { return }

            self.category = category
            readingPhase = .ready(adhkar)
        } catch {
            guard !Task.isCancelled else { return }
            readingPhase = .unavailable
        }
    }

    // MARK: Browsing

    /// The chapters that match what the reader typed, cut into their groups.
    ///
    /// Groups appear in the corpus's own order and vanish when a search empties them, so the
    /// screen never draws a heading with nothing under it. The chapters inside keep the order the
    /// repository returned, which is Hisn al-Muslim's own chapter sequence.
    var sections: [Section] {
        guard case .ready(let categories) = categoriesPhase else { return [] }

        let matching = categories.filter(matches)
        var sections: [Section] = []

        for group in AdhkarGroup.allCases {
            let inGroup = matching.filter { $0.group == group }
            if !inGroup.isEmpty {
                sections.append(Section(group: group, categories: inGroup))
            }
        }

        return sections
    }

    /// Whether anything at all matched. The screen's empty state, told apart from a corpus that
    /// could not be read.
    var hasSearchResults: Bool { !sections.isEmpty }

    var isSearching: Bool { !ArabicSearchQuery(searchText).tokens.isEmpty }

    /// Whether a chapter's title matches the query, in either language.
    ///
    /// Prefix matching rather than whole words: a reader typing `mosq` has not finished the word
    /// yet, and a search that only answers on the last keystroke reads as a broken one.
    ///
    /// The Arabic side goes through `ArabicSearchQuery`, the same folding the Quran and hadith
    /// corpora are indexed with — so `الوضوء` finds `الوضوء` whatever hamzas and diacritics either
    /// side happens to carry. The English side is lowercased before folding, which
    /// `ArabicSearchQuery` deliberately does not do: it exists to match an index built from
    /// Arabic, where case does not arise.
    private func matches(_ category: AdhkarCategory) -> Bool {
        let query = ArabicSearchQuery(searchText.lowercased())
        guard !query.isEmpty else { return true }
        guard let haystack = searchIndex[category.id] else { return false }

        return query.tokens.allSatisfy { token in
            haystack.contains { $0.hasPrefix(token) }
        }
    }

    private static func haystack(for category: AdhkarCategory) -> [String] {
        ArabicSearchQuery(category.titleArabic).tokens
            + ArabicSearchQuery(category.titleEnglish.lowercased()).tokens
    }

    // MARK: Counting

    /// How many times this dhikr has been said in the current session.
    func repeats(of dhikr: Dhikr) -> Int {
        repeatCounts[dhikr.id] ?? 0
    }

    /// Whether it has been said as many times as it asks for.
    func isComplete(_ dhikr: Dhikr) -> Bool {
        repeats(of: dhikr) >= dhikr.repeatCount
    }

    /// Records one recitation, stopping at `repeatCount`.
    ///
    /// Clamped rather than left to run on: the count is what the screen shows against the
    /// target, and "12 of 10" is not a state anyone wants to read.
    ///
    /// - Returns: whether *this* tap was the one that finished it. The reading screen turns that
    ///   into the move to the next dhikr and the second haptic, both of which belong to the
    ///   crossing rather than to the count — the same distinction `QiblaViewModel.isAlignedWithQibla`
    ///   draws, and for the same reason: firing on the state would fire on every redraw.
    @discardableResult
    func countRepeat(of dhikr: Dhikr) -> Bool {
        let counted = repeats(of: dhikr)
        guard counted < dhikr.repeatCount else { return false }

        repeatCounts[dhikr.id] = counted + 1
        recordActivity()
        return counted + 1 >= dhikr.repeatCount
    }

    /// Starts this dhikr again — a mis-tap, or a second reading.
    func resetRepeats(of dhikr: Dhikr) {
        repeatCounts[dhikr.id] = nil
        recordActivity()
    }

    /// The dhikr after this one, or `nil` at the end of the chapter.
    func dhikr(after dhikr: Dhikr) -> Dhikr? {
        guard case .ready(let adhkar) = readingPhase,
              let index = adhkar.firstIndex(of: dhikr),
              index + 1 < adhkar.count else { return nil }

        return adhkar[index + 1]
    }

    /// Reports how far through the open chapter the reader is, for Home's chip.
    ///
    /// Debounced by the recorder, which is why it can be called from every tap: a hundred-count
    /// dhikr must not be a hundred saves of a number only the last value of matters.
    private func recordActivity() {
        guard let category, totalCount > 0 else { return }

        activity?.record(
            .adhkar(categoryID: category.id, completed: completedCount, of: totalCount, at: Date())
        )
    }

    /// Writes anything the debounce is still holding. Driven from the reading screen's
    /// `onDisappear` — leaving straight after the last tap is exactly when the delay would
    /// otherwise lose it.
    func flushActivity() async {
        await activity?.flush()
    }

    /// How many adhkar in the loaded chapter have been completed, for the progress line at the
    /// top of the reading screen.
    /// `filter` rather than `count(where:)`, which needs iOS 18 and this app targets 17.
    var completedCount: Int {
        guard case .ready(let adhkar) = readingPhase else { return 0 }
        return adhkar.filter(isComplete).count
    }

    /// How many there are to get through.
    var totalCount: Int {
        guard case .ready(let adhkar) = readingPhase else { return 0 }
        return adhkar.count
    }

    /// Whether every dhikr in the chapter has been said its full number of times.
    var isChapterComplete: Bool {
        totalCount > 0 && completedCount == totalCount
    }
}
