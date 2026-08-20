//
//  QuranProgressRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Against a real in-memory SwiftData store rather than a fake, because what is under test here
/// *is* the storage: the single-row position, and the uniqueness the schema cannot express on a
/// pair of columns and the repository therefore has to enforce itself.
struct QuranProgressRepositoryTests {

    private func makeRepository() throws -> QuranProgressRepository {
        let persistence = try PersistenceController(inMemory: true)
        return QuranProgressRepository(modelContainer: persistence.container)
    }

    private let kursi = VerseReference(surah: 2, verse: 255)
    private let opening = VerseReference(surah: 1, verse: 1)

    // MARK: Bookmarks

    @Test func keepsAVerseAndReadsItBack() async throws {
        let repository = try makeRepository()

        try await repository.addBookmark(kursi, at: Date())
        let bookmarks = try await repository.bookmarks()

        #expect(bookmarks.map(\.reference) == [kursi])
    }

    @Test func startsWithNothingKept() async throws {
        let repository = try makeRepository()

        #expect(try await repository.bookmarks().isEmpty)
    }

    /// The pair (surah, verse) has to be unique and `@Attribute(.unique)` cannot say so — see
    /// `QuranBookmarkRecord`. This is the test that the repository does it instead.
    @Test func keepingTheSameVerseTwiceDoesNotDuplicateIt() async throws {
        let repository = try makeRepository()

        try await repository.addBookmark(kursi, at: Date())
        try await repository.addBookmark(kursi, at: Date())

        #expect(try await repository.bookmarks().count == 1)
    }

    /// Re-saving must not reorder the list. The rows are ordered by `createdAt`, so overwriting
    /// it would move a verse the reader already had to the top of their bookmarks unbidden.
    @Test func keepingAVerseAgainLeavesItsDateAlone() async throws {
        let repository = try makeRepository()
        let original = Date(timeIntervalSince1970: 1_000)

        try await repository.addBookmark(kursi, at: original)
        try await repository.addBookmark(kursi, at: Date(timeIntervalSince1970: 9_000))

        #expect(try await repository.bookmarks().first?.createdAt == original)
    }

    @Test func newestKeptVerseComesFirst() async throws {
        let repository = try makeRepository()

        try await repository.addBookmark(opening, at: Date(timeIntervalSince1970: 1_000))
        try await repository.addBookmark(kursi, at: Date(timeIntervalSince1970: 2_000))

        #expect(try await repository.bookmarks().map(\.reference) == [kursi, opening])
    }

    @Test func forgetsAVerse() async throws {
        let repository = try makeRepository()

        try await repository.addBookmark(kursi, at: Date())
        try await repository.addBookmark(opening, at: Date())
        try await repository.removeBookmark(kursi)

        #expect(try await repository.bookmarks().map(\.reference) == [opening])
    }

    @Test func forgettingSomethingUnkeptIsNotAnError() async throws {
        let repository = try makeRepository()

        try await repository.removeBookmark(kursi)

        #expect(try await repository.bookmarks().isEmpty)
    }

    /// Two verses that differ only in one component must not be confused — the predicate matches
    /// on both columns, and a bug that dropped one would silently unbookmark the wrong verse.
    @Test func versesAreKeptApartByBothChapterAndNumber() async throws {
        let repository = try makeRepository()

        try await repository.addBookmark(VerseReference(surah: 2, verse: 1), at: Date())
        try await repository.addBookmark(VerseReference(surah: 1, verse: 2), at: Date())
        try await repository.removeBookmark(VerseReference(surah: 2, verse: 1))

        #expect(try await repository.bookmarks().map(\.reference) == [VerseReference(surah: 1, verse: 2)])
    }

    // MARK: Last read

    @Test func hasNoPositionBeforeAnythingIsRead() async throws {
        let repository = try makeRepository()

        #expect(try await repository.lastRead() == nil)
    }

    @Test func recordsWhereTheReaderLeftOff() async throws {
        let repository = try makeRepository()
        let when = Date(timeIntervalSince1970: 5_000)

        try await repository.recordLastRead(kursi, at: when)
        let position = try await repository.lastRead()

        #expect(position?.reference == kursi)
        #expect(position?.updatedAt == when)
    }

    /// The row is a singleton: reading again replaces the position rather than appending, or the
    /// store would grow with every sitting.
    @Test func recordingAgainReplacesThePosition() async throws {
        let repository = try makeRepository()

        try await repository.recordLastRead(opening, at: Date(timeIntervalSince1970: 1_000))
        try await repository.recordLastRead(kursi, at: Date(timeIntervalSince1970: 2_000))

        #expect(try await repository.lastRead()?.reference == kursi)
    }

    /// Bookmarks and the position are separate rows in separate tables — keeping a verse must
    /// not move where the reader is, and vice versa.
    @Test func bookmarksAndPositionDoNotDisturbEachOther() async throws {
        let repository = try makeRepository()

        try await repository.recordLastRead(opening, at: Date())
        try await repository.addBookmark(kursi, at: Date())

        #expect(try await repository.lastRead()?.reference == opening)
        #expect(try await repository.bookmarks().map(\.reference) == [kursi])
    }
}
