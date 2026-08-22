//
//  MemorizeHadithUseCase.swift
//  ThawabForGod
//

import Foundation

/// The review session: what is due, what answering does, and what starting and stopping mean.
///
/// Where the three pieces meet — the schedule store, the corpus the narrations come out of, and
/// the scheduler that decides when to ask again. Each is useless alone and none of them should
/// know about the other two, which is what a use case is for.
nonisolated struct MemorizeHadithUseCase: Sendable {
    private let memorization: any HadithMemorizationRepositoring
    private let corpus: any HadithRepositoring
    private let scheduler: SpacedRepetitionScheduler

    init(
        memorization: any HadithMemorizationRepositoring,
        corpus: any HadithRepositoring,
        scheduler: SpacedRepetitionScheduler = SpacedRepetitionScheduler()
    ) {
        self.memorization = memorization
        self.corpus = corpus
        self.scheduler = scheduler
    }

    // MARK: The deck

    /// Everything the reader is memorizing, whether due or not.
    func deck() async throws -> [HadithReviewCard] {
        try await cards(for: memorization.all())
    }

    /// The cards due on `date`, longest-overdue first.
    ///
    /// The order comes from the store rather than being re-sorted here, and it is the order the
    /// session asks in — see `HadithMemorizationRepositoring.due(on:)`.
    func due(on date: Date = Date()) async throws -> [HadithReviewCard] {
        try await cards(for: memorization.due(on: date))
    }

    /// How many are due, without reading a single narration out of the corpus.
    ///
    /// Its own method because the collections screen wants the number and nothing else, and
    /// joining fifteen thousand characters of Arabic onto it to display "3" would be work done
    /// for nothing.
    func dueCount(on date: Date = Date()) async throws -> Int {
        try await memorization.due(on: date).count
    }

    /// Whether a narration is in the deck at all.
    func isMemorizing(_ id: HadithID, in deck: [HadithMemorization]) -> Bool {
        deck.contains { $0.id == id }
    }

    // MARK: Starting and stopping

    /// Adds a narration to the deck, due immediately.
    ///
    /// Due now rather than tomorrow: the reader has just decided to memorize it, and the one
    /// moment they certainly want to see it is this one.
    func start(_ hadith: Hadith, on date: Date = Date()) async throws {
        try await memorization.add(
            HadithMemorization(hadith, state: scheduler.newState(on: date))
        )
    }

    /// Takes a narration out of the deck, forgetting its schedule.
    ///
    /// **The schedule really is forgotten**, rather than kept in case they come back. Keeping it
    /// would mean a reader who stopped six months ago and started again being asked to recall
    /// something on a six-month interval they have long since lost — which is worse than starting
    /// over, and silently so.
    func stop(_ id: HadithID) async throws {
        try await memorization.remove(id)
    }

    /// Adds it if it is not in the deck, and takes it out if it is.
    ///
    /// One method rather than two, because the button is one button — the same shape
    /// `HadithProgressUseCase.toggleBookmark(_:)` takes.
    func toggle(_ hadith: Hadith, on date: Date = Date()) async throws {
        let inDeck = try await memorization.all().contains { $0.id == hadith.id }

        if inDeck {
            try await stop(hadith.id)
        } else {
            try await start(hadith, on: date)
        }
    }

    // MARK: Answering

    /// Records how a card went and schedules it again.
    ///
    /// The arithmetic is `SpacedRepetitionScheduler`'s and the storage is the repository's; what
    /// this adds is only that the two happen together. Returns the new state so a screen can say
    /// when the narration will come back without re-reading the store.
    @discardableResult
    func answer(
        _ card: HadithReviewCard,
        with grade: ReviewGrade,
        on date: Date = Date()
    ) async throws -> MemorizationState {
        let state = scheduler.next(card.memorization.state, grade: grade, on: date)

        try await memorization.update(
            HadithMemorization(
                id: card.id,
                bookNumber: card.memorization.bookNumber,
                state: state
            )
        )

        return state
    }

    // MARK: The join

    /// Puts the schedules back together with the narrations they are schedules for.
    ///
    /// A schedule whose narration the corpus no longer has is dropped rather than shown as a card
    /// with nothing on it — the same failure mode `HadithProgressUseCase.bookmarks()` handles,
    /// and for the same reason.
    ///
    /// The store's order is preserved rather than the corpus's, because the store's order is the
    /// one that means something: soonest due first.
    private func cards(for schedules: [HadithMemorization]) async throws -> [HadithReviewCard] {
        guard !schedules.isEmpty else { return [] }

        let narrations = try await corpus.hadiths(schedules.map(\.id))
        let byID = Dictionary(
            narrations.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return schedules.compactMap { schedule in
            byID[schedule.id].map { HadithReviewCard(memorization: schedule, hadith: $0) }
        }
    }
}
