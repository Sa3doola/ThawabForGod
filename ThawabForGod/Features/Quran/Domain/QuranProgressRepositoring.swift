//
//  QuranProgressRepositoring.swift
//  ThawabForGod
//

import Foundation

/// The reader's own marks in the text: what they kept, and where they left off.
///
/// The other half of the Quran's storage split. `QuranRepositoring` reads a corpus nobody can
/// change; this reads and writes the only part of the feature that belongs to the reader. Both
/// sit behind protocols in this same folder so the view model cannot tell which is which — the
/// shape `TasbihCatalogProviding` and `TasbihProgressRepositoring` already set.
///
/// One protocol for both because they are one question asked two ways, they share a store, and
/// splitting them would mean two `@ModelActor`s and two contexts for six small methods.
///
/// `async` throughout: the implementation is a `@ModelActor` running off the main actor. Callers
/// re-fetch after a write — there is no `@Query` behind a repository.
nonisolated protocol QuranProgressRepositoring: Sendable {

    /// Every kept verse, newest first.
    func bookmarks() async throws -> [QuranBookmark]

    /// Keeps a verse. Doing this twice for the same verse is not an error and does not produce a
    /// second row — see `QuranBookmark`, where the verse *is* the key.
    func addBookmark(_ reference: VerseReference, at date: Date) async throws

    /// Forgets a verse. A no-op when it was not kept.
    func removeBookmark(_ reference: VerseReference) async throws

    /// Where the reader left off, or `nil` before they have read anything.
    func lastRead() async throws -> ReadingPosition?

    /// Replaces the stored position. There is only ever one.
    func recordLastRead(_ reference: VerseReference, at date: Date) async throws
}
