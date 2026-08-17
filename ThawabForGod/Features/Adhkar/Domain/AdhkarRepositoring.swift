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
/// - Note: `language` is a parameter rather than something the repository was built with,
///   because the choice can change while the app is running. The reading screen re-fetches when
///   it does, which is cheaper and far less error-prone than caching two languages' worth of
///   text against a language nobody has selected yet.
nonisolated protocol AdhkarRepositoring: Sendable {

    /// The categories the corpus actually contains, in reading order.
    ///
    /// Read from the database rather than returned from `AdhkarCategory.allCases`, so a category
    /// the app knows about but the bundled data has no rows for never reaches the screen.
    func categories() async throws -> [AdhkarCategory]

    /// The adhkar in a category, in reading order, resolved to one language.
    func adhkar(in category: AdhkarCategory, language: AppLanguage) async throws -> [Dhikr]
}
