//
//  TafsirRepository.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// `TafsirRepositoring` over the bundled tafsir packs: one read-only database per pack, opened on
/// first use, every query off the main actor.
///
/// **Silence is `nil`** (T16). A QUL tafsir gives every ayah a row, pointing at the group whose
/// owner carries the text; Tafsir al-Jalalayn has no row at all for the 226 ayahs its authors pass
/// over. Mushaf would have thrown for those. Here the answer is `nil`, and the screen says this
/// commentary has no note on this ayah — never a neighbour's note, which would print a gloss of one
/// verse under another.
actor TafsirRepository: TafsirRepositoring {
    private let store: any ContentPackStoring
    private let index: QuranAyahIndex
    private var open: [ContentPackID: CorpusDatabase] = [:]

    init(store: any ContentPackStoring, index: QuranAyahIndex) {
        self.store = store
        self.index = index
    }

    func installed() async -> [ContentPack] {
        await store.installed().filter { $0.kind == .tafsir }
    }

    func tafsir(for ayah: VerseReference, pack: ContentPackID) async throws -> TafsirEntry? {
        guard let database = await database(pack) else { throw ContentPackError.notInstalled(pack) }
        guard let id = try index.id(of: ayah) else { return nil }

        // The asked ayah's group owner carries the text; the group's members give the range.
        let row = try await database.reader().read { db -> (html: String?, first: Int, last: Int)? in
            guard let group = try Int.fetchOne(db, sql: "SELECT group_ayah_id FROM tafsir WHERE ayah_id = ?", arguments: [id]) else {
                return nil
            }
            let html = try String.fetchOne(db, sql: "SELECT html FROM tafsir WHERE ayah_id = ?", arguments: [group])
            let span = try Row.fetchOne(db, sql: "SELECT min(ayah_id), max(ayah_id) FROM tafsir WHERE group_ayah_id = ?", arguments: [group])
            return (html, span?[0] ?? group, span?[1] ?? group)
        }
        // No row and no group: the commentary is silent here.
        guard let row else { return nil }
        guard let html = row.html, !html.isEmpty,
              let first = try index.reference(of: row.first), let last = try index.reference(of: row.last)
        else {
            // The builder makes this impossible: every group's owner has text.
            throw QuranDataError.invalidRow("\(pack): no text for \(ayah)'s group")
        }
        return TafsirEntry(pack: pack, ayah: ayah, range: first...last, html: html)
    }

    /// The pack's database, or nil for a pack that is not a bundled tafsir.
    private func database(_ pack: ContentPackID) async -> CorpusDatabase? {
        if let database = open[pack] { return database }
        guard await installed().contains(where: { $0.id == pack }), let url = await store.url(for: pack) else { return nil }
        let database = CorpusDatabase(url: url)
        open[pack] = database
        return database
    }
}
