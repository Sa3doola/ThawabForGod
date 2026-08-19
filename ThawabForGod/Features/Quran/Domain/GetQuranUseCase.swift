//
//  GetQuranUseCase.swift
//  ThawabForGod
//

import Foundation

/// What the Quran screens ask for: the two ways into the text, and the text itself.
///
/// A thin composition over the repository, and thin on purpose — the same shape as
/// `GetAdhkarUseCase`. It exists so the view models depend on the feature's own vocabulary
/// rather than on a storage protocol, which is what lets a later slice land here without a
/// screen noticing: the last-read position folded into the surah list, a translation joined
/// onto the verses, a bookmark marked on them.
nonisolated struct GetQuranUseCase: Sendable {
    private let repository: any QuranRepositoring

    init(repository: any QuranRepositoring) {
        self.repository = repository
    }

    func surahs() async throws -> [Surah] {
        try await repository.surahs()
    }

    func surah(_ number: Int) async throws -> Surah? {
        try await repository.surah(number)
    }

    func verses(inSurah surahNumber: Int) async throws -> [Verse] {
        try await repository.verses(inSurah: surahNumber)
    }

    func juzList() async throws -> [Juz] {
        try await repository.juzList()
    }

    func verses(inJuz juz: Int) async throws -> [Verse] {
        try await repository.verses(inJuz: juz)
    }
}
