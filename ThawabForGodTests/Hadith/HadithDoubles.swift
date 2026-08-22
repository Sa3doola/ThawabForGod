//
//  HadithDoubles.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// Something to fail with that is `Sendable`, unlike `any Error`.
nonisolated struct HadithStubError: Error, Equatable {}

/// The corpus on demand, and a record of what was asked for.
///
/// Locked rather than an `actor`, for the reason `StubQuranRepository` is: `HadithRepositoring`
/// is a `nonisolated` protocol, and an actor cannot witness one.
///
/// Safety invariant for `@unchecked Sendable`: `_requests` is only ever touched while `lock` is
/// held, and nothing else here is mutable.
nonisolated final class StubHadithRepository: HadithRepositoring, @unchecked Sendable {

    /// What was asked of the repository, in order — enough to tell "list the divisions of
    /// Bukhari" apart from "read Bukhari's first division", which is the one confusion a stack
    /// two pushes deep can make silently.
    enum Request: Equatable {
        case collections
        case books(String)
        case book(BookReference)
        case hadiths(BookReference)
        case hadithsByID([HadithID])
        case search(ArabicSearchQuery)
    }

    private let lock = NSLock()
    private let collectionsResult: Result<[HadithCollection], HadithStubError>
    private let booksResult: Result<[HadithBook], HadithStubError>
    private let hadithsResult: Result<[Hadith], HadithStubError>
    private let searchResult: Result<HadithSearchResults, HadithStubError>
    private var _requests: [Request] = []

    var requests: [Request] { lock.withLock { _requests } }

    init(
        collections: Result<[HadithCollection], HadithStubError> = .success([.stub()]),
        books: Result<[HadithBook], HadithStubError> = .success([.stub()]),
        hadiths: Result<[Hadith], HadithStubError> = .success([.stub()]),
        search: Result<HadithSearchResults, HadithStubError> = .success(.none)
    ) {
        collectionsResult = collections
        booksResult = books
        hadithsResult = hadiths
        searchResult = search
    }

    private func record(_ request: Request) {
        lock.withLock { _requests.append(request) }
    }

    func collections() async throws -> [HadithCollection] {
        record(.collections)
        return try collectionsResult.get()
    }

    func books(inCollection collectionID: String) async throws -> [HadithBook] {
        record(.books(collectionID))
        return try booksResult.get()
    }

    /// The division whose number was asked for, out of whatever `books` was stubbed with — so a
    /// test that stubs one list gets a consistent answer from both methods rather than having to
    /// stub the same thing twice.
    func book(_ reference: BookReference) async throws -> HadithBook? {
        record(.book(reference))
        return try booksResult.get().first { $0.number == reference.number }
    }

    func hadiths(inBook reference: BookReference) async throws -> [Hadith] {
        record(.hadiths(reference))
        return try hadithsResult.get()
    }

    func search(_ query: ArabicSearchQuery, limit: Int) async throws -> HadithSearchResults {
        record(.search(query))
        return try searchResult.get()
    }

    /// The narrations among `hadiths` whose identities were asked for — so a test that stubs one
    /// list gets a consistent answer here too rather than having to stub the same thing twice.
    func hadiths(_ ids: [HadithID]) async throws -> [Hadith] {
        record(.hadithsByID(ids))
        let wanted = Set(ids)
        return try hadithsResult.get().filter { wanted.contains($0.id) }
    }
}

// MARK: Fixtures

nonisolated extension HadithCollection {
    static func stub(
        id: String = "bukhari",
        bookCount: Int = 97,
        hadithCount: Int = 7580
    ) -> HadithCollection {
        HadithCollection(
            id: id,
            arabicName: "صحيح البخاري",
            englishName: "Sahih al-Bukhari",
            arabicAuthor: "الإمام محمد بن إسماعيل البخاري",
            englishAuthor: "Imam Muhammad ibn Isma'il al-Bukhari",
            bookCount: bookCount,
            hadithCount: hadithCount
        )
    }
}

nonisolated extension HadithBook {
    static func stub(
        collectionID: String = "bukhari",
        number: Int = 1,
        hadithCount: Int = 7
    ) -> HadithBook {
        HadithBook(
            collectionID: collectionID,
            number: number,
            arabicTitle: "كتاب بدء الوحى",
            englishTitle: "Revelation",
            hadithCount: hadithCount
        )
    }
}

nonisolated extension Hadith {
    static func stub(
        collectionID: String = "bukhari",
        bookNumber: Int = 1,
        number: Int = 1,
        part: Int = 0,
        last: Int? = nil,
        text: String = "إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ"
    ) -> Hadith {
        Hadith(
            id: HadithID(collection: collectionID, number: number, part: part),
            bookNumber: bookNumber,
            reference: HadithReference(collection: collectionID, first: number, last: last),
            text: text
        )
    }
}

/// A store that remembers what it was told, without SwiftData.
///
/// Locked rather than an `actor`, for the reason `StubHadithRepository` is: the protocol it
/// witnesses is `nonisolated`, and an actor cannot witness one.
///
/// Safety invariant for `@unchecked Sendable`: every stored property is touched only while
/// `lock` is held.
nonisolated final class StubHadithProgressRepository: HadithProgressRepositoring, @unchecked Sendable {
    private let lock = NSLock()
    private var _bookmarks: [HadithBookmark]
    private var _lastRead: HadithReadingPosition?
    private let failure: HadithStubError?

    var stored: [HadithBookmark] { lock.withLock { _bookmarks } }

    init(
        bookmarks: [HadithBookmark] = [],
        lastRead: HadithReadingPosition? = nil,
        failure: HadithStubError? = nil
    ) {
        _bookmarks = bookmarks
        _lastRead = lastRead
        self.failure = failure
    }

    func bookmarks() async throws -> [HadithBookmark] {
        if let failure { throw failure }
        return lock.withLock { _bookmarks.sorted { $0.createdAt > $1.createdAt } }
    }

    func addBookmark(_ bookmark: HadithBookmark) async throws {
        if let failure { throw failure }
        lock.withLock {
            guard !_bookmarks.contains(where: { $0.id == bookmark.id }) else { return }
            _bookmarks.append(bookmark)
        }
    }

    func removeBookmark(_ id: HadithID) async throws {
        if let failure { throw failure }
        lock.withLock { _bookmarks.removeAll { $0.id == id } }
    }

    func lastRead() async throws -> HadithReadingPosition? {
        if let failure { throw failure }
        return lock.withLock { _lastRead }
    }

    func recordLastRead(_ book: BookReference, at date: Date) async throws {
        if let failure { throw failure }
        lock.withLock { _lastRead = HadithReadingPosition(book: book, updatedAt: date) }
    }
}

/// A memorization deck that remembers what it was told, without SwiftData.
///
/// Locked rather than an `actor`, for the reason the two stubs above are: the protocol it
/// witnesses is `nonisolated`, and an actor cannot witness one.
///
/// Safety invariant for `@unchecked Sendable`: `_deck` is touched only while `lock` is held.
nonisolated final class StubHadithMemorizationRepository: HadithMemorizationRepositoring, @unchecked Sendable {
    private let lock = NSLock()
    private var _deck: [HadithMemorization]
    private let failure: HadithStubError?

    var deck: [HadithMemorization] { lock.withLock { _deck } }

    init(deck: [HadithMemorization] = [], failure: HadithStubError? = nil) {
        _deck = deck
        self.failure = failure
    }

    func all() async throws -> [HadithMemorization] {
        if let failure { throw failure }
        return lock.withLock { _deck }
    }

    func due(on date: Date) async throws -> [HadithMemorization] {
        if let failure { throw failure }
        return lock.withLock {
            _deck.filter { $0.state.isDue(on: date) }
                .sorted { $0.state.dueOn < $1.state.dueOn }
        }
    }

    func add(_ memorization: HadithMemorization) async throws {
        if let failure { throw failure }
        lock.withLock {
            guard !_deck.contains(where: { $0.id == memorization.id }) else { return }
            _deck.append(memorization)
        }
    }

    func remove(_ id: HadithID) async throws {
        if let failure { throw failure }
        lock.withLock { _deck.removeAll { $0.id == id } }
    }

    func update(_ memorization: HadithMemorization) async throws {
        if let failure { throw failure }
        lock.withLock {
            guard let index = _deck.firstIndex(where: { $0.id == memorization.id }) else { return }
            _deck[index] = memorization
        }
    }
}
