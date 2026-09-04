//
//  AdhkarRepositoring.swift
//  ThawabForGod
//

import Foundation

/// Reads adhkar. The feature depends on this, never on GRDB or SQL.
///
/// `async` for the same reason `BookmarkRepository` is: the implementation reads a database off
/// the main actor, and a screen must not block a frame waiting on a file. Nothing here is a
/// write — the corpus is read-only, and a reader's progress through it is transient state the
/// view model holds, not a row.
///
/// **No `language` parameter any more.** It used to take one, because the corpus stored an English
/// translation of each dhikr and a row had to be resolved down to one language before it left the
/// Data layer. Hisn al-Muslim's text is Arabic and only Arabic, and the one thing that does have
/// two spellings — a chapter's title — is carried in both on `AdhkarCategory`, so a language
/// change is a redraw rather than a re-fetch.
nonisolated protocol AdhkarRepositoring: Sendable {

    /// Every chapter the corpus holds, in the book's own order.
    ///
    /// All 132 in one read, deliberately: the whole list is a few kilobytes of title, the browse
    /// screen groups and searches across all of them, and paging it would buy nothing but a
    /// second failure mode.
    func categories() async throws -> [AdhkarCategory]

    /// One chapter, by its slug — `nil` where this build knows a slug the corpus does not, which
    /// is what a deep link saved by an older install can hand it.
    func category(id: String) async throws -> AdhkarCategory?

    /// The adhkar in a chapter, in reading order.
    func adhkar(in category: AdhkarCategory) async throws -> [Dhikr]
}
