//
//  HadithProgressTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The real SwiftData store, in memory — bookmarks and the one position row.
@MainActor
struct HadithProgressRepositoryTests {

    private func makeRepository() throws -> HadithProgressRepository {
        let persistence = try PersistenceController(inMemory: true)
        return HadithProgressRepository(modelContainer: persistence.container)
    }

    private let first = HadithID(collection: "bukhari", number: 1)
    private let second = HadithID(collection: "muslim", number: 8)

    @Test func nothingIsKeptToBeginWith() async throws {
        #expect(try await makeRepository().bookmarks().isEmpty)
    }

    @Test func aKeptNarrationComesBack() async throws {
        let repository = try makeRepository()

        try await repository.addBookmark(HadithBookmark(id: first, bookNumber: 1))
        let kept = try await repository.bookmarks()

        #expect(kept.map(\.id) == [first])
        #expect(kept.first?.bookNumber == 1)
    }

    /// **The identity is the narration**, so keeping the same one twice is idempotent rather than
    /// a second row the reader cannot tell apart from the first.
    @Test func keepingTheSameNarrationTwiceLeavesOneRow() async throws {
        let repository = try makeRepository()
        let bookmark = HadithBookmark(id: first, bookNumber: 1)

        try await repository.addBookmark(bookmark)
        try await repository.addBookmark(bookmark)

        #expect(try await repository.bookmarks().count == 1)
    }

    /// Re-keeping must not move a narration to the top of the list. The list is ordered by when
    /// it was kept, so overwriting the date would reorder the reader's bookmarks for no reason
    /// they asked for.
    @Test func keepingItAgainDoesNotChangeWhenItWasKept() async throws {
        let repository = try makeRepository()
        let original = Date(timeIntervalSince1970: 1_000)

        try await repository.addBookmark(
            HadithBookmark(id: first, bookNumber: 1, createdAt: original)
        )
        try await repository.addBookmark(
            HadithBookmark(id: first, bookNumber: 1, createdAt: Date())
        )

        #expect(try await repository.bookmarks().first?.createdAt == original)
    }

    /// **The part is part of the key.** Sahih al-Bukhari prints two narrations under one number
    /// in twenty-six places, and keeping one must not be indistinguishable from keeping the other.
    @Test func twoNarrationsUnderOneNumberAreKeptSeparately() async throws {
        let repository = try makeRepository()
        let plain = HadithID(collection: "bukhari", number: 402, part: 0)
        let second = HadithID(collection: "bukhari", number: 402, part: 1)

        try await repository.addBookmark(HadithBookmark(id: plain, bookNumber: 8))
        try await repository.addBookmark(HadithBookmark(id: second, bookNumber: 8))

        #expect(try await repository.bookmarks().count == 2)
    }

    /// So is the collection. Bukhari 1 and Muslim 1 are different narrations under one number.
    @Test func theSameNumberInTwoCollectionsIsTwoBookmarks() async throws {
        let repository = try makeRepository()

        try await repository.addBookmark(
            HadithBookmark(id: HadithID(collection: "bukhari", number: 1), bookNumber: 1)
        )
        try await repository.addBookmark(
            HadithBookmark(id: HadithID(collection: "muslim", number: 1), bookNumber: 1)
        )

        #expect(try await repository.bookmarks().count == 2)
    }

    @Test func bookmarksComeBackNewestFirst() async throws {
        let repository = try makeRepository()

        try await repository.addBookmark(
            HadithBookmark(id: first, bookNumber: 1, createdAt: Date(timeIntervalSince1970: 100))
        )
        try await repository.addBookmark(
            HadithBookmark(id: second, bookNumber: 1, createdAt: Date(timeIntervalSince1970: 200))
        )

        #expect(try await repository.bookmarks().map(\.id) == [second, first])
    }

    @Test func forgettingRemovesIt() async throws {
        let repository = try makeRepository()

        try await repository.addBookmark(HadithBookmark(id: first, bookNumber: 1))
        try await repository.removeBookmark(first)

        #expect(try await repository.bookmarks().isEmpty)
    }

    @Test func forgettingSomethingNeverKeptIsHarmless() async throws {
        let repository = try makeRepository()

        try await repository.removeBookmark(first)

        #expect(try await repository.bookmarks().isEmpty)
    }

    // MARK: The position

    @Test func thereIsNoPositionBeforeAnythingIsRead() async throws {
        #expect(try await makeRepository().lastRead() == nil)
    }

    /// **There is only ever one.** A second write replaces the first rather than accumulating,
    /// which is the whole reason the position is a separate row and not a flag on a bookmark.
    @Test func recordingAPositionReplacesTheOneBefore() async throws {
        let repository = try makeRepository()
        let bukhari = BookReference(collection: "bukhari", number: 1)
        let muslim = BookReference(collection: "muslim", number: 12)

        try await repository.recordLastRead(bukhari, at: Date(timeIntervalSince1970: 100))
        try await repository.recordLastRead(muslim, at: Date(timeIntervalSince1970: 200))

        #expect(try await repository.lastRead()?.book == muslim)
    }
}

/// The join back to the corpus, which is what makes a bookmark readable.
@MainActor
struct HadithProgressUseCaseTests {

    private let first = Hadith.stub(number: 1, text: "الأول")
    private let second = Hadith.stub(collectionID: "muslim", bookNumber: 3, number: 8, text: "الثاني")

    private func makeUseCase(
        bookmarks: [HadithBookmark] = [],
        corpus: [Hadith]? = nil
    ) -> (HadithProgressUseCase, StubHadithProgressRepository) {
        let progress = StubHadithProgressRepository(bookmarks: bookmarks)
        let useCase = HadithProgressUseCase(
            progress: progress,
            corpus: StubHadithRepository(hadiths: .success(corpus ?? [first, second]))
        )
        return (useCase, progress)
    }

    @Test func noBookmarksMeansNoCorpusRead() async throws {
        let repository = StubHadithRepository()
        let useCase = HadithProgressUseCase(
            progress: StubHadithProgressRepository(),
            corpus: repository
        )

        #expect(try await useCase.bookmarks().isEmpty)
        #expect(repository.requests.isEmpty)
    }

    /// The bookmark and its narration arrive as one value, so a row cannot be drawn with one
    /// reader's date over another's text.
    @Test func aBookmarkComesBackWithItsNarration() async throws {
        let (useCase, _) = makeUseCase(bookmarks: [HadithBookmark(first)])

        let kept = try await useCase.bookmarks()

        #expect(kept.count == 1)
        #expect(kept.first?.hadith.text == "الأول")
        #expect(kept.first?.id == first.id)
    }

    /// Ordered by when it was kept, not by where it sits in the collections — the list is a record
    /// of what the reader did.
    @Test func keptNarrationsStayInTheOrderTheyWereKept() async throws {
        let (useCase, _) = makeUseCase(bookmarks: [
            HadithBookmark(first, createdAt: Date(timeIntervalSince1970: 100)),
            HadithBookmark(second, createdAt: Date(timeIntervalSince1970: 200))
        ])

        #expect(try await useCase.bookmarks().map(\.id) == [second.id, first.id])
    }

    /// A bookmark the corpus no longer has is dropped rather than shown as a citation with no
    /// text under it. It cannot happen today; it is what a rebuild that regrouped a narration
    /// would produce.
    @Test func aBookmarkTheCorpusHasLostIsDropped() async throws {
        let (useCase, _) = makeUseCase(
            bookmarks: [HadithBookmark(first), HadithBookmark(second)],
            corpus: [first]
        )

        #expect(try await useCase.bookmarks().map(\.id) == [first.id])
    }

    @Test func togglingKeepsWhatWasNotKept() async throws {
        let (useCase, store) = makeUseCase()

        try await useCase.toggleBookmark(first)

        #expect(store.stored.map(\.id) == [first.id])
    }

    @Test func togglingForgetsWhatWasKept() async throws {
        let (useCase, store) = makeUseCase(bookmarks: [HadithBookmark(first)])

        try await useCase.toggleBookmark(first)

        #expect(store.stored.isEmpty)
    }
}
