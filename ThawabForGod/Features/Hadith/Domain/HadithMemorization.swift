//
//  HadithMemorization.swift
//  ThawabForGod
//

import Foundation

/// A narration the reader is memorizing, and where it stands in its schedule.
///
/// **Not a bookmark.** The two marks mean different things and are stored apart: a bookmark is a
/// ribbon — "come back to this" — while this is a commitment to be asked about it. Folding them
/// together would mean every kept narration turning up in the review queue, which is the fastest
/// way to make a reader stop keeping things.
///
/// The narration itself is not here, for the reason it is not on `HadithBookmark`: the words
/// belong to the corpus and the schedule belongs to the reader. `MemorizeHadithUseCase` puts them
/// back together.
nonisolated struct HadithMemorization: Identifiable, Hashable, Sendable {

    /// Which narration, which is also the row's key — one schedule per narration, always.
    let id: HadithID

    /// Which kitab it sits in, so a card can be opened in its place without a second lookup.
    let bookNumber: Int

    /// Where it stands: easiness, repetitions, interval, next due date.
    let state: MemorizationState

    init(id: HadithID, bookNumber: Int, state: MemorizationState) {
        self.id = id
        self.bookNumber = bookNumber
        self.state = state
    }

    init(_ hadith: Hadith, state: MemorizationState) {
        self.init(id: hadith.id, bookNumber: hadith.bookNumber, state: state)
    }

    /// Where in the tab this narration lives.
    var book: BookReference {
        BookReference(collection: id.collection, number: bookNumber)
    }
}

/// A card in the review queue: the schedule, and the narration it is a schedule for.
///
/// One value rather than two parallel arrays, so a card cannot be drawn with one narration's text
/// over another's due date — the same reason `KeptHadith` exists.
///
/// `ReviewCard` rather than `Card`, because `HadithCard` is already the view that draws a
/// narration on the reading screen. Two things called the same thing in one feature is a
/// confusion the compiler would not catch and a reader would.
nonisolated struct HadithReviewCard: Identifiable, Hashable, Sendable {
    let memorization: HadithMemorization
    let hadith: Hadith

    var id: HadithID { memorization.id }
}

/// The reader's memorization schedule for the hadith.
///
/// A third store-facing protocol in this feature, beside `HadithRepositoring` (the corpus) and
/// `HadithProgressRepositoring` (bookmarks and position). Its own rather than more methods on the
/// second, because a schedule is a different kind of thing from a ribbon and the two have no
/// query in common — and because a `Memorize` feature spanning the adhkar and the divine names,
/// which the plan calls for, will want this shape rather than the bookmarks'.
///
/// `async` throughout: the implementation is a `@ModelActor` running off the main actor. Callers
/// re-fetch after a write.
nonisolated protocol HadithMemorizationRepositoring: Sendable {

    /// Every narration being memorized, whether or not it is due.
    func all() async throws -> [HadithMemorization]

    /// Those due on or before `date`, soonest-due first.
    ///
    /// Taking the date rather than reading a clock, so a test can ask what the queue looks like
    /// next Tuesday without waiting until Tuesday.
    func due(on date: Date) async throws -> [HadithMemorization]

    /// Starts memorizing a narration, or leaves an existing schedule alone.
    ///
    /// Leaving it alone matters: adding a narration the reader is already three weeks into would
    /// otherwise reset it to a new item and undo the work.
    func add(_ memorization: HadithMemorization) async throws

    /// Stops memorizing a narration, forgetting its schedule. A no-op when it was not being
    /// memorized.
    func remove(_ id: HadithID) async throws

    /// Replaces a narration's schedule with the one an answer produced.
    func update(_ memorization: HadithMemorization) async throws
}
