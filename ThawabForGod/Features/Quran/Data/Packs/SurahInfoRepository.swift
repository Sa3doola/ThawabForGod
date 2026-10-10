//
//  SurahInfoRepository.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// `SurahInfoRepositoring` over the bundled surah-info packs: one read-only database per pack,
/// opened on first use, every query off the main actor. A public build has no such pack, and
/// `installed()` is empty.
actor SurahInfoRepository: SurahInfoRepositoring {
    private let store: any ContentPackStoring
    private var open: [ContentPackID: CorpusDatabase] = [:]

    init(store: any ContentPackStoring) {
        self.store = store
    }

    func installed() async -> [ContentPack] {
        await store.installed().filter { $0.kind == .surahInfo }
    }

    func pack(for language: AppLanguage) async -> ContentPack? {
        await installed().first { $0.language == language.rawValue }
    }

    func info(surah: Int, pack: ContentPackID) async throws -> SurahInfo? {
        guard let database = await database(pack) else { return nil }
        return try await database.reader().read { db in
            try Row.fetchOne(db, sql: "SELECT summary, html FROM surah_info WHERE surah = ?", arguments: [surah]).map {
                SurahInfo(pack: pack, surah: surah, summary: $0[0], html: $0[1])
            }
        }
    }

    /// The pack's database, or nil for a pack that is not a bundled surah-info pack.
    private func database(_ pack: ContentPackID) async -> CorpusDatabase? {
        if let database = open[pack] { return database }
        guard await installed().contains(where: { $0.id == pack }), let url = await store.url(for: pack) else { return nil }
        let database = CorpusDatabase(url: url)
        open[pack] = database
        return database
    }
}
