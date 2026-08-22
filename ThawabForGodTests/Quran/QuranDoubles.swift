//
//  QuranDoubles.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// Something to fail with that is `Sendable`, unlike `any Error`.
nonisolated struct QuranStubError: Error, Equatable {}

/// The corpus on demand, and a record of what was asked for.
///
/// Locked rather than an `actor`, for the reason `StubNamesRepository` is: `QuranRepositoring` is
/// a `nonisolated` protocol, and an actor cannot witness one.
///
/// Safety invariant for `@unchecked Sendable`: `requests` is only ever touched while `lock` is
/// held, and nothing else here is mutable.
nonisolated final class StubQuranRepository: QuranRepositoring, @unchecked Sendable {

    /// What was asked of the repository, in order — enough to tell "read chapter 2" apart from
    /// "read part 2", which is the one confusion this feature can make silently.
    enum Request: Equatable {
        case surahs
        case surah(Int)
        case versesInSurah(Int)
        case juzList
        case versesInJuz(Int)
        case search(ArabicSearchQuery)
    }

    private let lock = NSLock()
    private let surahResult: Result<[Surah], QuranStubError>
    private let verseResult: Result<[Verse], QuranStubError>
    private let juzResult: Result<[Juz], QuranStubError>
    private let searchResult: Result<QuranSearchResults, QuranStubError>
    private var _requests: [Request] = []

    var requests: [Request] { lock.withLock { _requests } }

    init(
        surahs: Result<[Surah], QuranStubError> = .success([.stub()]),
        verses: Result<[Verse], QuranStubError> = .success([.stub()]),
        juz: Result<[Juz], QuranStubError> = .success([.stub()]),
        search: Result<QuranSearchResults, QuranStubError> = .success(.none)
    ) {
        surahResult = surahs
        verseResult = verses
        juzResult = juz
        searchResult = search
    }

    private func record(_ request: Request) {
        lock.withLock { _requests.append(request) }
    }

    func surahs() async throws -> [Surah] {
        record(.surahs)
        return try surahResult.get()
    }

    func surah(_ number: Int) async throws -> Surah? {
        record(.surah(number))
        return try surahResult.get().first { $0.id == number }
    }

    func verses(inSurah surahNumber: Int) async throws -> [Verse] {
        record(.versesInSurah(surahNumber))
        return try verseResult.get()
    }

    func juzList() async throws -> [Juz] {
        record(.juzList)
        return try juzResult.get()
    }

    func verses(inJuz juz: Int) async throws -> [Verse] {
        record(.versesInJuz(juz))
        return try verseResult.get()
    }

    func search(_ query: ArabicSearchQuery, limit: Int) async throws -> QuranSearchResults {
        record(.search(query))
        return try searchResult.get()
    }
}

/// The reader's marks, in memory, with a record of what was written.
///
/// Locked rather than an `actor` for the same reason `StubQuranRepository` is: the protocol it
/// witnesses is `nonisolated`.
///
/// Safety invariant for `@unchecked Sendable`: every stored property below is only ever touched
/// while `lock` is held.
nonisolated final class StubQuranProgressRepository: QuranProgressRepositoring, @unchecked Sendable {

    enum Write: Equatable {
        case added(VerseReference)
        case removed(VerseReference)
        case recordedPosition(VerseReference)
    }

    private let lock = NSLock()
    private var _bookmarks: [QuranBookmark]
    private var _position: ReadingPosition?
    private var _writes: [Write] = []
    private let failure: QuranStubError?

    var writes: [Write] { lock.withLock { _writes } }

    init(
        bookmarks: [QuranBookmark] = [],
        position: ReadingPosition? = nil,
        failure: QuranStubError? = nil
    ) {
        self._bookmarks = bookmarks
        self._position = position
        self.failure = failure
    }

    private func check() throws {
        if let failure { throw failure }
    }

    func bookmarks() async throws -> [QuranBookmark] {
        try check()
        return lock.withLock { _bookmarks }
    }

    func addBookmark(_ reference: VerseReference, at date: Date) async throws {
        try check()
        lock.withLock {
            _writes.append(.added(reference))
            guard !_bookmarks.contains(where: { $0.reference == reference }) else { return }
            _bookmarks.insert(QuranBookmark(reference: reference, createdAt: date), at: 0)
        }
    }

    func removeBookmark(_ reference: VerseReference) async throws {
        try check()
        lock.withLock {
            _writes.append(.removed(reference))
            _bookmarks.removeAll { $0.reference == reference }
        }
    }

    func lastRead() async throws -> ReadingPosition? {
        try check()
        return lock.withLock { _position }
    }

    func recordLastRead(_ reference: VerseReference, at date: Date) async throws {
        try check()
        lock.withLock {
            _writes.append(.recordedPosition(reference))
            _position = ReadingPosition(reference: reference, updatedAt: date)
        }
    }
}

nonisolated extension Surah {

    /// A chapter with everything filled in, so a test only names the field it cares about.
    static func stub(
        id: Int = 1,
        arabicName: String = "الفاتحة",
        transliteration: String = "Al-Faatiha",
        englishName: String = "The Opening",
        verseCount: Int = 7,
        revelationPlace: RevelationPlace = .meccan,
        revelationOrder: Int = 5,
        bismillah: String? = nil
    ) -> Surah {
        Surah(
            id: id,
            arabicName: arabicName,
            transliteration: transliteration,
            englishName: englishName,
            verseCount: verseCount,
            revelationPlace: revelationPlace,
            revelationOrder: revelationOrder,
            bismillah: bismillah
        )
    }
}

nonisolated extension Verse {
    static func stub(
        surah: Int = 1,
        number: Int = 1,
        text: String = "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ",
        juz: Int = 1,
        hizb: Int = 1,
        rubElHizb: Int = 1,
        page: Int = 1,
        sajda: Sajda? = nil
    ) -> Verse {
        Verse(
            id: VerseReference(surah: surah, verse: number),
            text: text,
            juz: juz,
            hizb: hizb,
            rubElHizb: rubElHizb,
            page: page,
            sajda: sajda
        )
    }
}

nonisolated extension Juz {
    static func stub(
        number: Int = 1,
        start: VerseReference = VerseReference(surah: 1, verse: 1),
        end: VerseReference = VerseReference(surah: 2, verse: 141)
    ) -> Juz {
        Juz(id: number, start: start, end: end)
    }
}
