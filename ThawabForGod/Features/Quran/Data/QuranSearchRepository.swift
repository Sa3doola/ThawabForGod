//
//  QuranSearchRepository.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// `QuranSearchRepositoring` over `ayah_fts` in the bundled Quran database (each word and, since
/// schema 3, its stems) and `pack_fts` in each translation pack. Both indexes are contentless: a
/// match gives the ayah id (the rowid), and the text comes from the ayah or translation table.
///
/// Mushaf opened a second queue on `quran.sqlite` for search. Here it reads through the same
/// `CorpusDatabase` the Quran repository does — one connection to the file — and packs through
/// their own, joined to references by `QuranAyahIndex`. Every query runs off the main actor.
actor QuranSearchRepository: QuranSearchRepositoring {
    private let quran: any CorpusDatabaseProviding
    private let store: any ContentPackStoring
    private let index: QuranAyahIndex
    private var open: [ContentPackID: CorpusDatabase] = [:]

    init(quran: any CorpusDatabaseProviding, store: any ContentPackStoring, index: QuranAyahIndex) {
        self.quran = quran
        self.store = store
        self.index = index
    }

    func searchQuran(_ query: QuranSearchQuery) async throws -> QuranSearchResult {
        try await quran.reader().read { db in
            // `exact` is 1 when every word matched in its own form (text_norm only).
            let rows = try Row.fetchAll(db, sql: """
                SELECT a.surah, a.ayah, ayah_fts.rowid IN (SELECT rowid FROM ayah_fts WHERE ayah_fts MATCH ?) AS exact
                FROM ayah_fts JOIN ayah a ON a.id = ayah_fts.rowid
                WHERE ayah_fts MATCH ? ORDER BY ayah_fts.rowid
                """, arguments: [query.exactArabicExpression, query.arabicExpression])
            var result = QuranSearchResult(exact: [], attached: [])
            for row in rows {
                let ayah = VerseReference(surah: row[0], verse: row[1])
                if row["exact"] as Bool { result.exact.append(ayah) } else { result.attached.append(ayah) }
            }
            return result
        }
    }

    func searchTranslations(_ query: QuranSearchQuery, packs ids: [ContentPackID]) async throws -> [TranslationText] {
        var result: [TranslationText] = []
        for pack in ids {
            guard let database = await database(pack) else { continue }
            let rows = try await database.reader().read { db in
                try Row.fetchAll(db, sql: """
                    SELECT t.ayah_id, t.text, t.footnotes_json FROM pack_fts
                    JOIN translation t ON t.ayah_id = pack_fts.rowid
                    WHERE pack_fts MATCH ? ORDER BY pack_fts.rowid
                    """, arguments: [query.ftsExpression]).map { (id: $0[0] as Int, text: $0[1] as String, footnotes: $0[2] as String?) }
            }
            for row in rows {
                guard let ayah = try index.reference(of: row.id) else { continue }
                result.append(TranslationRepository.translation(pack: pack, ayah: ayah, text: row.text, footnotes: row.footnotes))
            }
        }
        return result
    }

    /// A translation pack's database; nil for a pack that is not a bundled translation.
    private func database(_ pack: ContentPackID) async -> CorpusDatabase? {
        if let database = open[pack] { return database }
        guard await store.installed().contains(where: { $0.id == pack && $0.kind == .translation }),
              let url = await store.url(for: pack)
        else { return nil }
        let database = CorpusDatabase(url: url)
        open[pack] = database
        return database
    }
}
