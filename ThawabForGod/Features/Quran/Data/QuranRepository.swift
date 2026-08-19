//
//  QuranRepository.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// Serves the Quran out of its own bundled database.
///
/// **The only type in the feature that knows SQL exists.** Everything above it — the use case,
/// the view models, every view — is written against `QuranRepositoring` and domain values, which
/// is what lets the whole feature be tested without a database.
///
/// A different file from the one the adhkar, the tasbih and the 99 names share: the text is an
/// order of magnitude larger than all of those together and has a different upstream and a
/// different licence, so it gets its own `CorpusDatabase`. Nothing about that is visible here —
/// this type is handed a reader and never learns which file is behind it.
///
/// Reads run off the main actor without this type arranging anything: GRDB dispatches the body
/// of `read` onto the database's own serial queue and resumes the caller when it returns, so a
/// query cannot land on a frame no matter which actor asked for it.
nonisolated struct QuranRepository: QuranRepositoring {
    private let database: any CorpusDatabaseProviding

    init(database: any CorpusDatabaseProviding) {
        self.database = database
    }

    func surahs() async throws -> [Surah] {
        let records = try await database.reader().read { database in
            try SurahRecord.fetchAll(database, sql: "SELECT * FROM surah ORDER BY id")
        }

        // `compactMap` rather than a force-unwrap: a corpus rebuilt with a revelation place this
        // build has no case for should cost that chapter its row, not trap the list.
        return records.compactMap(\.domainValue)
    }

    func surah(_ number: Int) async throws -> Surah? {
        let record = try await database.reader().read { database in
            try SurahRecord.fetchOne(
                database,
                sql: "SELECT * FROM surah WHERE id = ?",
                arguments: [number]
            )
        }

        return record?.domainValue
    }

    func verses(inSurah surahNumber: Int) async throws -> [Verse] {
        let records = try await database.reader().read { database in
            try VerseRecord.fetchAll(
                database,
                sql: "SELECT * FROM verse WHERE surah_id = ? ORDER BY number",
                arguments: [surahNumber]
            )
        }

        // Mapped out here rather than inside the `read`, so the connection is handed back as
        // soon as the rows are in hand and the database queue is never held for view work.
        return records.map(\.domainValue)
    }

    func juzList() async throws -> [Juz] {
        let records = try await database.reader().read { database in
            try JuzRecord.fetchAll(database, sql: "SELECT * FROM juz ORDER BY number")
        }

        return records.map(\.domainValue)
    }

    func verses(inJuz juz: Int) async throws -> [Verse] {
        // Filtered on the verse's own `juz` column rather than joined against the range in the
        // `juz` table. The column is written at build time for exactly this, and it turns a
        // query that would have to compare a chapter-and-verse pair against two bounds into an
        // equality test — the one part of the schema that pays for itself on every read.
        let records = try await database.reader().read { database in
            try VerseRecord.fetchAll(
                database,
                sql: "SELECT * FROM verse WHERE juz = ? ORDER BY surah_id, number",
                arguments: [juz]
            )
        }

        return records.map(\.domainValue)
    }
}
