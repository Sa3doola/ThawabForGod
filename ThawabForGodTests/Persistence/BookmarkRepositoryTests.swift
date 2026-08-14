//
//  BookmarkRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

struct BookmarkRepositoryTests {

    private func makeRepository() throws -> SwiftDataBookmarkRepository {
        let persistence = try PersistenceController(inMemory: true)
        return SwiftDataBookmarkRepository(modelContainer: persistence.container)
    }

    @Test func startsEmpty() async throws {
        let repository = try makeRepository()

        #expect(try await repository.bookmarks().isEmpty)
    }

    @Test func addsAndReadsBack() async throws {
        let repository = try makeRepository()
        let bookmark = Bookmark(reference: "2:255", note: "Ayat al-Kursi")

        try await repository.add(bookmark)

        let stored = try await repository.bookmarks()
        #expect(stored == [bookmark])
        #expect(try await repository.bookmark(id: bookmark.id) == bookmark)
    }

    @Test func sortsNewestFirst() async throws {
        let repository = try makeRepository()
        let older = Bookmark(reference: "1:1", createdAt: Date(timeIntervalSince1970: 1_000))
        let newer = Bookmark(reference: "18:10", createdAt: Date(timeIntervalSince1970: 2_000))

        try await repository.add(older)
        try await repository.add(newer)

        #expect(try await repository.bookmarks().map(\.reference) == ["18:10", "1:1"])
    }

    @Test func updatesInPlace() async throws {
        let repository = try makeRepository()
        var bookmark = Bookmark(reference: "36:1")
        try await repository.add(bookmark)

        bookmark.note = "Ya-Sin"
        try await repository.update(bookmark)

        let stored = try await repository.bookmarks()
        #expect(stored.count == 1)
        #expect(stored.first?.note == "Ya-Sin")
    }

    @Test func deletesById() async throws {
        let repository = try makeRepository()
        let kept = Bookmark(reference: "1:1")
        let removed = Bookmark(reference: "2:255")
        try await repository.add(kept)
        try await repository.add(removed)

        try await repository.delete(id: removed.id)

        let stored = try await repository.bookmarks()
        #expect(stored.map(\.id) == [kept.id])
        #expect(try await repository.bookmark(id: removed.id) == nil)
    }

    @Test func ignoresUnknownIdentifiers() async throws {
        let repository = try makeRepository()
        try await repository.add(Bookmark(reference: "1:1"))

        try await repository.delete(id: UUID())
        try await repository.update(Bookmark(reference: "9:9"))

        #expect(try await repository.bookmarks().count == 1)
    }

    @Test func writesFromTheModelActorSurviveANewContext() async throws {
        // Proves the write reaches the store, not just the actor's own context.
        let persistence = try PersistenceController(inMemory: true)
        let repository = SwiftDataBookmarkRepository(modelContainer: persistence.container)
        let bookmark = Bookmark(reference: "112:1")

        try await repository.add(bookmark)

        let second = SwiftDataBookmarkRepository(modelContainer: persistence.container)
        #expect(try await second.bookmarks() == [bookmark])
    }
}
