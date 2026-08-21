//
//  TafsirRepository.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// Serves the commentaries out of their own bundled database.
///
/// A third corpus file, read through a third `CorpusDatabase` — which costs nothing, because that
/// type is constructed with a resource name and knows nothing about what is inside it. Its own
/// file rather than more tables in `quran.sqlite` for the reason that one was split off
/// `corpus.sqlite`: a different upstream, a different licence, and a size that grows with every
/// edition added.
///
/// Reads land off the main actor without this type arranging anything — GRDB dispatches the body
/// of `read` onto the database's own queue whatever actor asked.
nonisolated struct TafsirRepository: TafsirRepositoring {
    private let database: any CorpusDatabaseProviding

    init(database: any CorpusDatabaseProviding) {
        self.database = database
    }

    func editions() async throws -> [TafsirEdition] {
        let records = try await database.reader().read { database in
            try TafsirEditionRecord.fetchAll(database, sql: "SELECT * FROM edition ORDER BY id")
        }

        return records.compactMap(\.domainValue)
    }

    func note(
        for reference: VerseReference,
        in edition: TafsirEdition.ID
    ) async throws -> TafsirNote? {
        let found = try await database.reader().read { database in
            // The edition is read in the same transaction as the note, so the note cannot come
            // back attributed to an edition row that a rebuild has since changed underneath it.
            let editionRecord = try TafsirEditionRecord.fetchOne(
                database,
                sql: "SELECT * FROM edition WHERE id = ?",
                arguments: [edition]
            )

            let text = try String.fetchOne(
                database,
                sql: """
                    SELECT text FROM tafsir
                    WHERE edition_id = ? AND surah_id = ? AND number = ?
                    """,
                arguments: [edition, reference.surah, reference.verse]
            )

            return (editionRecord, text)
        }

        // No row is the commentary's silence, and it is returned as such. See
        // `TafsirRepositoring.note(for:in:)` — 226 verses have no note in al-Jalalayn, and
        // reaching for a neighbouring row to fill the gap would print a gloss of one verse
        // under another.
        guard let text = found.1, let edition = found.0?.domainValue else { return nil }

        return TafsirNote(reference: reference, edition: edition, text: text)
    }
}
