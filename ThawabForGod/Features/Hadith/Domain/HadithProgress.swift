//
//  HadithProgress.swift
//  ThawabForGod
//

import Foundation

/// A narration the reader has kept.
///
/// **The narration is the identity**, exactly as it is in `QuranBookmark`: a bookmark answers
/// "is this kept?", so keying it on anything else would allow the same narration to be saved
/// twice and leave the reader with two identical rows and no way to tell them apart. Toggling
/// becomes idempotent for free.
///
/// It carries no text. What a bookmark stores is a *reference*, and the narration it names is
/// read back out of the corpus — which is the storage split this project holds everywhere:
/// `hadith.sqlite` is content nobody can change, the SwiftData store is what the reader did.
/// Copying the words into the second one would make the bookmark stale the day the corpus is
/// rebuilt, and would put twenty-four megabytes of somebody else's text in a file that is meant
/// to hold only choices.
nonisolated struct HadithBookmark: Identifiable, Hashable, Sendable {

    /// Which narration, which is also the row's key.
    let id: HadithID

    /// Which kitab it sits in.
    ///
    /// Stored rather than looked up, and it is the one piece of denormalization here. The
    /// bookmarks list needs it to open the reading screen, and fetching every narration only to
    /// learn which division it is in would be a second round trip to answer a question the
    /// corpus already answered once.
    let bookNumber: Int

    /// When it was kept — what the list is ordered by, newest first, because the reason to open
    /// this list is usually the thing just saved.
    let createdAt: Date

    init(id: HadithID, bookNumber: Int, createdAt: Date = Date()) {
        self.id = id
        self.bookNumber = bookNumber
        self.createdAt = createdAt
    }

    init(_ hadith: Hadith, createdAt: Date = Date()) {
        self.init(id: hadith.id, bookNumber: hadith.bookNumber, createdAt: createdAt)
    }

    /// Where in the tab this bookmark leads.
    var book: BookReference {
        BookReference(collection: id.collection, number: bookNumber)
    }
}

/// Where the reader last was in the hadith.
///
/// One of these exists at a time, which is what separates it from a `HadithBookmark`: a bookmark
/// is chosen and accumulates, a position is a side effect of reading and is overwritten. Stored
/// apart for that reason rather than as a bookmark with a flag on it — a "current" flag on a list
/// means every write has to clear the flag on whatever held it before, and one row that is simply
/// replaced cannot get out of step with itself. The same argument `ReadingPosition` makes.
///
/// **A kitab, not a narration.** The Quran resumes at a verse because a verse is where a reader
/// stops; a kitab of hadith is read a narration at a time and put down between them, and being
/// returned to the exact paragraph would more often be wrong than right. What the reader wants
/// back is the division they were in.
nonisolated struct HadithReadingPosition: Hashable, Sendable {

    /// The kitab to resume in.
    let book: BookReference

    /// When the reader was last there. Shown nowhere yet; stored because "continue reading" is
    /// the kind of affordance that eventually wants to say how long ago.
    let updatedAt: Date

    init(book: BookReference, updatedAt: Date = Date()) {
        self.book = book
        self.updatedAt = updatedAt
    }
}

/// The reader's own marks in the hadith: what they kept, and where they left off.
///
/// The other half of this feature's storage split. `HadithRepositoring` reads a corpus nobody can
/// change; this reads and writes the only part of the feature that belongs to the reader. Both
/// sit behind protocols in this same folder so the view model cannot tell which is which — the
/// shape `QuranRepositoring` and `QuranProgressRepositoring` already set.
///
/// `async` throughout: the implementation is a `@ModelActor` running off the main actor. Callers
/// re-fetch after a write — there is no `@Query` behind a repository.
nonisolated protocol HadithProgressRepositoring: Sendable {

    /// Every kept narration, newest first.
    func bookmarks() async throws -> [HadithBookmark]

    /// Keeps a narration. Doing this twice is not an error and does not produce a second row —
    /// see `HadithBookmark`, where the narration *is* the key.
    func addBookmark(_ bookmark: HadithBookmark) async throws

    /// Forgets a narration. A no-op when it was not kept.
    func removeBookmark(_ id: HadithID) async throws

    /// Which kitab the reader left off in, or `nil` before they have read anything.
    func lastRead() async throws -> HadithReadingPosition?

    /// Replaces the stored position. There is only ever one.
    func recordLastRead(_ book: BookReference, at date: Date) async throws
}
