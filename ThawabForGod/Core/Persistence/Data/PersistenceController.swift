//
//  PersistenceController.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// Owns the app's single `ModelContainer`.
///
/// Scope: **mutable user data only** — bookmarks, counts, progress. The read-only religious
/// corpus ships as its own bundled store (`Core/Persistence/Corpus`); do not add it here.
///
/// Every new `@Model` type must be listed in `schema` or it will not be persisted.
nonisolated struct PersistenceController: Sendable {
    let container: ModelContainer

    static let schema = Schema([
        BookmarkRecord.self,
        TasbihSessionModel.self,
        QuranBookmarkRecord.self,
        ReadingPositionRecord.self,
        RecentActivityRecord.self
    ])

    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(
            schema: Self.schema,
            isStoredInMemoryOnly: inMemory
        )
        self.container = try ModelContainer(for: Self.schema, configurations: [configuration])
    }

    /// The on-disk store the app runs on. A failure here means the store is unreadable and
    /// there is nothing sensible to fall back to, so it is fatal by design.
    static func makeDefault() -> PersistenceController {
        do {
            return try PersistenceController()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
