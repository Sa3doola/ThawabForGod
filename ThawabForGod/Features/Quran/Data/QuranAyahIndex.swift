//
//  QuranAyahIndex.swift
//  ThawabForGod
//

import Foundation
import GRDB
import os

/// The global ayah id (1…6,236, `ayah.id`) of every verse, and back.
///
/// Packs are keyed by that id, and so is the search index. Mushaf joined them to the Quran by
/// `ATTACH`ing `quran.sqlite` to every pack's connection; here each pack opens on its own through
/// `CorpusDatabase` and the join is this table, read once from the chosen Quran database — 6,236
/// pairs, a few hundred kilobytes. Both builds number the ayahs the same way (canonical order, and
/// `Tools/QuranBuilder` tests that), so a pack built against either reads correctly with either.
nonisolated final class QuranAyahIndex: Sendable {
    private struct Table: Sendable {
        let references: [VerseReference]
        let ids: [VerseReference: Int]
    }

    private let database: any CorpusDatabaseProviding
    /// Loaded on first use. Invariant: nothing suspends inside `withLock`; the read is a
    /// synchronous GRDB call.
    private let cache = OSAllocatedUnfairLock<Table?>(initialState: nil)

    init(database: any CorpusDatabaseProviding) {
        self.database = database
    }

    /// The ayah's global id, or nil for a reference outside the Quran.
    func id(of reference: VerseReference) throws -> Int? {
        try table().ids[reference]
    }

    /// The global ids of a surah's ayahs, first to last, or nil for a surah outside 1…114.
    func ids(inSurah surah: Int) throws -> ClosedRange<Int>? {
        let references = try table().references
        guard let first = references.firstIndex(where: { $0.surah == surah }),
              let last = references.lastIndex(where: { $0.surah == surah })
        else { return nil }
        return (first + 1)...(last + 1)
    }

    /// The reference of a global id, or nil for an id outside 1…6,236.
    func reference(of id: Int) throws -> VerseReference? {
        let references = try table().references
        return references.indices.contains(id - 1) ? references[id - 1] : nil
    }

    private func table() throws -> Table {
        try cache.withLock { cached in
            if let cached { return cached }
            let rows = try database.reader().read { db in
                try Row.fetchAll(db, sql: "SELECT id, surah, ayah FROM ayah ORDER BY id")
                    .map { (id: $0[0] as Int, reference: VerseReference(surah: $0[1], verse: $0[2])) }
            }
            // Ids are positions: the builder writes them 1…6,236 in canonical order.
            guard rows.enumerated().allSatisfy({ $0.offset + 1 == $0.element.id }) else {
                throw QuranDataError.invalidRow("ayah ids are not 1…\(rows.count) in order")
            }
            let table = Table(
                references: rows.map(\.reference),
                ids: Dictionary(uniqueKeysWithValues: rows.map { ($0.reference, $0.id) })
            )
            cached = table
            return table
        }
    }
}
