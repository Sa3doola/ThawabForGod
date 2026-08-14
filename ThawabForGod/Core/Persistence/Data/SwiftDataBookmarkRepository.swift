//
//  SwiftDataBookmarkRepository.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData-backed bookmarks.
///
/// `@ModelActor` gives this actor its own `ModelContext` on its own executor, so reads and
/// writes happen off the main actor and never touch the context SwiftUI uses. Only `Bookmark`
/// values cross the boundary — never a `BookmarkRecord`.
@ModelActor
actor SwiftDataBookmarkRepository: BookmarkRepository {

    func bookmarks() throws -> [Bookmark] {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainValue)
    }

    func bookmark(id: UUID) throws -> Bookmark? {
        try record(id: id)?.domainValue
    }

    func add(_ bookmark: Bookmark) throws {
        modelContext.insert(BookmarkRecord(bookmark))
        try modelContext.save()
    }

    func update(_ bookmark: Bookmark) throws {
        guard let record = try record(id: bookmark.id) else { return }
        record.apply(bookmark)
        try modelContext.save()
    }

    func delete(id: UUID) throws {
        guard let record = try record(id: id) else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    private func record(id: UUID) throws -> BookmarkRecord? {
        var descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
