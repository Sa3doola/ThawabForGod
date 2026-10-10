//
//  TranslationRepository.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// `TranslationRepositoring` over the bundled translation packs: one read-only database per pack,
/// opened on first use, every query off the main actor.
///
/// Mushaf `ATTACH`ed `quran.sqlite` to each pack to find rows by surah and ayah. Here every pack
/// opens through `CorpusDatabase` on its own, and `QuranAyahIndex` turns a reference into the
/// global ayah id the pack is keyed by — the same join, without a pack's connection having to know
/// which Quran database was bundled.
actor TranslationRepository: TranslationRepositoring {
    private let store: any ContentPackStoring
    private let index: QuranAyahIndex
    private var open: [ContentPackID: CorpusDatabase] = [:]

    init(store: any ContentPackStoring, index: QuranAyahIndex) {
        self.store = store
        self.index = index
    }

    func installed() async -> [ContentPack] {
        await store.installed().filter { $0.kind == .translation }
    }

    func text(for ayah: VerseReference, packs: [ContentPackID]) async throws -> [TranslationText] {
        guard let id = try index.id(of: ayah) else { return [] }
        var result: [TranslationText] = []
        for pack in packs {
            guard let database = await database(pack) else { continue }
            let row = try await database.reader().read { db in
                try Row.fetchOne(db, sql: "SELECT text, footnotes_json FROM translation WHERE ayah_id = ?", arguments: [id])
                    .map { (text: $0[0] as String, footnotes: $0[1] as String?) }
            }
            if let row { result.append(Self.translation(pack: pack, ayah: ayah, text: row.text, footnotes: row.footnotes)) }
        }
        return result
    }

    func texts(surah: Int, pack: ContentPackID) async throws -> [VerseReference: TranslationText] {
        guard let database = await database(pack) else { throw ContentPackError.notInstalled(pack) }
        guard let ids = try index.ids(inSurah: surah) else { return [:] }
        let rows = try await database.reader().read { db in
            try Row.fetchAll(db, sql: """
                SELECT ayah_id, text, footnotes_json FROM translation WHERE ayah_id BETWEEN ? AND ? ORDER BY ayah_id
                """, arguments: [ids.lowerBound, ids.upperBound]).map { (id: $0[0] as Int, text: $0[1] as String, footnotes: $0[2] as String?) }
        }
        var result: [VerseReference: TranslationText] = [:]
        for row in rows {
            guard let ayah = try index.reference(of: row.id) else { continue }
            result[ayah] = Self.translation(pack: pack, ayah: ayah, text: row.text, footnotes: row.footnotes)
        }
        return result
    }

    /// The pack's database, or nil for a pack that is not a bundled translation.
    private func database(_ pack: ContentPackID) async -> CorpusDatabase? {
        if let database = open[pack] { return database }
        guard await installed().contains(where: { $0.id == pack }), let url = await store.url(for: pack) else { return nil }
        let database = CorpusDatabase(url: url)
        open[pack] = database
        return database
    }

    static func translation(pack: ContentPackID, ayah: VerseReference, text: String, footnotes: String?) -> TranslationText {
        let notes = footnotes.flatMap { try? JSONDecoder().decode([String: String].self, from: Data($0.utf8)) } ?? [:]
        return TranslationText(pack: pack, ayah: ayah, text: text, footnotes: notes)
    }
}
