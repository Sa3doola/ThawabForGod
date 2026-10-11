//
//  QuranRepositoryDoubles.swift
//  ThawabForGodTests
//

import Foundation
import os
@testable import ThawabForGod

/// A repository that reads the public database through the real code, counts the reads, and
/// fails on request.
///
/// **A class behind a lock, not an `actor`**, and at file scope, as `AdhkarDoubles.swift` keeps its
/// stub. It was an actor nested in `QuranReaderViewModelTests` until a second suite built one from
/// another file: from then on the iOS build, and only some builds of it, rejected a `nonisolated`
/// the compiler had inferred for the actor itself ("'nonisolated' modifier cannot be applied to
/// this declaration"), whether the actor was nested or not and whether or not it spelled out its
/// initializer. A final class whose stored properties are all `let` and `Sendable` needs no
/// inference at all. The counters and the switch stay `async` to read and set, so the tests that
/// were written against the actor `await` them as before.
nonisolated final class CountingQuranRepository: QuranRepositoring {
    private struct State {
        var capabilityReads = 0
        var corpusReads = 0
        var failing = false
    }

    private let base = QuranTestData.repository(QuranTestData.publicDatabase)
    private let state = OSAllocatedUnfairLock(initialState: State())

    var capabilityReads: Int {
        get async { state.withLock { $0.capabilityReads } }
    }

    var corpusReads: Int {
        get async { state.withLock { $0.corpusReads } }
    }

    func setFailing(_ failing: Bool) async {
        state.withLock { $0.failing = failing }
    }

    @concurrent func capabilities() async throws -> QuranCapabilities {
        let failing = state.withLock { state in
            state.capabilityReads += 1
            return state.failing
        }
        if failing { throw StubError() }
        return .text
    }

    @concurrent func loadCorpus(style: MushafStyleID) async throws -> QuranCorpus {
        let failing = state.withLock { state in
            state.corpusReads += 1
            return state.failing
        }
        if failing { throw StubError() }
        return try await base.loadCorpus(style: style)
    }

    @concurrent func surahs(style: MushafStyleID) async throws -> [Surah] {
        try await base.surahs(style: style)
    }

    @concurrent func page(_ number: Int, style: MushafStyleID) async throws -> MushafPage {
        try await base.page(number, style: style)
    }

    @concurrent func ayahs(surah: Int, style: MushafStyleID) async throws -> [Ayah] {
        try await base.ayahs(surah: surah, style: style)
    }

    @concurrent func pageNumber(for ayah: VerseReference, style: MushafStyleID) async throws -> Int {
        try await base.pageNumber(for: ayah, style: style)
    }

    @concurrent func metadata(style: MushafStyleID) async throws -> QuranMetadata {
        try await base.metadata(style: style)
    }
}

/// Delegates to the real repository over the bundled packs and counts the reads, so a case can see
/// whether a second load went back to the repository. A class behind a lock for the reason
/// `CountingQuranRepository` is one.
nonisolated final class CountingSurahInfoRepository: SurahInfoRepositoring {
    private let base = SurahInfoRepository(store: QuranTestData.bundledPacks)
    private let reads = OSAllocatedUnfairLock(initialState: 0)

    var infoReads: Int {
        get async { reads.withLock { $0 } }
    }

    func installed() async -> [ContentPack] {
        await base.installed()
    }

    func pack(for language: AppLanguage) async -> ContentPack? {
        await base.pack(for: language)
    }

    func info(surah: Int, pack: ContentPackID) async throws -> SurahInfo? {
        reads.withLock { $0 += 1 }
        return try await base.info(surah: surah, pack: pack)
    }
}
