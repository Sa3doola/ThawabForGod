//
//  AdhkarViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives both adhkar screens: the list of categories, and the adhkar inside the one being read.
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

    /// What the category list has to show.
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

    // MARK: State

    private(set) var categoriesPhase: CategoriesPhase = .loading
    private(set) var readingPhase: ReadingPhase = .loading

    /// The category currently loaded, which is how a re-read in a different language is told
    /// apart from a move to a different category. Only the second clears the counters.
    private(set) var category: AdhkarCategory?

    /// How many times each dhikr has been said, keyed by id and scoped to `category`.
    ///
    /// Scoped rather than global because 16 of the corpus's adhkar appear under *both* headings:
    /// saying one ten times in the morning must not leave it already counted come evening.
    private var repeatCounts: [Dhikr.ID: Int] = [:]

    @ObservationIgnored private let useCase: GetAdhkarUseCase

    /// Where Home's recent-activity chip is fed from. Optional: reading the adhkar is unchanged
    /// without it.
    @ObservationIgnored private let activity: ActivityRecorder?

    init(useCase: GetAdhkarUseCase, activity: ActivityRecorder? = nil) {
        self.useCase = useCase
        self.activity = activity
    }

    // MARK: Loading

    /// Loads the categories the corpus actually holds.
    ///
    /// Driven from the list's `.task`, so SwiftUI owns its lifetime — there is no stored `Task`
    /// here and nothing to cancel by hand.
    func loadCategories() async {
        categoriesPhase = .loading

        do {
            let categories = try await useCase.categories()
            guard !Task.isCancelled else { return }
            categoriesPhase = .ready(categories)
        } catch {
            guard !Task.isCancelled else { return }
            categoriesPhase = .unavailable
        }
    }

    /// Loads one category's adhkar in one language.
    ///
    /// The language is passed in rather than read from a manager, so this type stays testable
    /// without one — and so the reading view can simply re-run its `.task` when the reader
    /// changes language, which re-fetches the translations without losing their place.
    func load(_ category: AdhkarCategory, language: AppLanguage) async {
        // A different category is a different reading session; the same one in another language
        // is the same session, and the taps stand.
        if category != self.category {
            repeatCounts.removeAll()
            self.category = category
        }

        readingPhase = .loading

        do {
            let adhkar = try await useCase.adhkar(in: category, language: language)
            // The task driving this is cancelled when the screen goes away or the language
            // changes again mid-fetch. Without this check the older, slower result would land
            // on top of the newer one.
            guard !Task.isCancelled else { return }
            readingPhase = .ready(adhkar)
        } catch {
            guard !Task.isCancelled else { return }
            readingPhase = .unavailable
        }
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
    func countRepeat(of dhikr: Dhikr) {
        let counted = repeats(of: dhikr)
        guard counted < dhikr.repeatCount else { return }
        repeatCounts[dhikr.id] = counted + 1
        recordActivity()
    }

    /// Starts this dhikr again — a mis-tap, or a second reading.
    func resetRepeats(of dhikr: Dhikr) {
        repeatCounts[dhikr.id] = nil
        recordActivity()
    }

    /// Reports how far through the open category the reader is, for Home's chip.
    ///
    /// Debounced by the recorder, which is why it can be called from every tap: a hundred-count
    /// dhikr must not be a hundred saves of a number only the last value of matters.
    private func recordActivity() {
        guard let category, totalCount > 0 else { return }

        activity?.record(
            .adhkar(category, completed: completedCount, of: totalCount, at: Date())
        )
    }

    /// Writes anything the debounce is still holding. Driven from the reading screen's
    /// `onDisappear` — leaving straight after the last tap is exactly when the delay would
    /// otherwise lose it.
    func flushActivity() async {
        await activity?.flush()
    }

    /// How many adhkar in the loaded category have been completed, for the progress line at the
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
}
