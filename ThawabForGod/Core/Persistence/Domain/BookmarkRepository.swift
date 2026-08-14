//
//  BookmarkRepository.swift
//  ThawabForGod
//

import Foundation

/// Read and write bookmarks. Features depend on this, never on SwiftData.
///
/// Everything is `async`: the implementation runs on a `ModelActor` off the main actor, so
/// a large fetch or a batch write never blocks a frame. Callers re-fetch after a mutation —
/// there is no live-updating equivalent of `@Query` behind a repository.
nonisolated protocol BookmarkRepository: Sendable {
    func bookmarks() async throws -> [Bookmark]
    func bookmark(id: UUID) async throws -> Bookmark?
    func add(_ bookmark: Bookmark) async throws
    func update(_ bookmark: Bookmark) async throws
    func delete(id: UUID) async throws
}
