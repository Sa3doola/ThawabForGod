//
//  HadithRepository.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// Serves the hadith out of their own bundled database.
///
/// **The only type in the feature that knows SQL exists.** Everything above it — the use case,
/// the view model, every view — is written against `HadithRepositoring` and domain values, which
/// is what lets the whole feature be tested without a database.
///
/// A fourth corpus file rather than more tables in one of the first three, for the reason the
/// Quran and the tafsir each got their own: a different upstream, a different licence, and
/// twenty-four megabytes that only a reader who opens this tab ever needs. Nothing about that is
/// visible here — this type is handed a reader and never learns which file is behind it.
///
/// Reads run off the main actor without this type arranging anything: GRDB dispatches the body
/// of `read` onto the database's own serial queue and resumes the caller when it returns, so a
/// query cannot land on a frame no matter which actor asked for it.
nonisolated struct HadithRepository: HadithRepositoring {
    private let database: any CorpusDatabaseProviding

    init(database: any CorpusDatabaseProviding) {
        self.database = database
    }

    func collections() async throws -> [HadithCollection] {
        // The two counts come out of the same query rather than out of two more. They are
        // correlated subqueries over indexed columns on a table of fifteen thousand rows, which
        // SQLite answers from the index without touching the text — the reason the corpus does
        // not store them is that a stored count is a second thing that has to stay true.
        let records = try await database.reader().read { database in
            try HadithCollectionRecord.fetchAll(
                database,
                sql: """
                    SELECT c.*,
                           (SELECT count(*) FROM book
                             WHERE collection_id = c.id) AS book_count,
                           (SELECT count(*) FROM hadith
                             WHERE collection_id = c.id) AS hadith_count
                      FROM collection c
                     ORDER BY c.ordinal
                    """
            )
        }

        return records.map(\.domainValue)
    }

    func books(inCollection collectionID: String) async throws -> [HadithBook] {
        let records = try await database.reader().read { database in
            try HadithBookRecord.fetchAll(
                database,
                sql: """
                    SELECT * FROM book
                     WHERE collection_id = ?
                     ORDER BY number
                    """,
                arguments: [collectionID]
            )
        }

        // Mapped out here rather than inside the `read`, so the connection is handed back as
        // soon as the rows are in hand and the database queue is never held for view work.
        return records.map(\.domainValue)
    }

    func book(_ reference: BookReference) async throws -> HadithBook? {
        let record = try await database.reader().read { database in
            try HadithBookRecord.fetchOne(
                database,
                sql: "SELECT * FROM book WHERE collection_id = ? AND number = ?",
                arguments: [reference.collection, reference.number]
            )
        }

        return record?.domainValue
    }

    func hadiths(inBook reference: BookReference) async throws -> [Hadith] {
        // Ordered by number *and* part: twenty-six of Bukhari's numbers carry two narrations,
        // and without the second column their order would be whatever the file happened to hold.
        let records = try await database.reader().read { database in
            try HadithRecord.fetchAll(
                database,
                sql: """
                    SELECT * FROM hadith
                     WHERE collection_id = ? AND book_number = ?
                     ORDER BY number, part
                    """,
                arguments: [reference.collection, reference.number]
            )
        }

        return records.map(\.domainValue)
    }

    func hadiths(_ ids: [HadithID]) async throws -> [Hadith] {
        guard !ids.isEmpty else { return [] }

        // One query with an `IN` over the triples rather than one per identity. The placeholders
        // are built from the count and every value is bound, so nothing an identity holds is ever
        // interpolated into SQL — which matters because `collection` is a string that came out of
        // a store the app writes.
        let placeholders = Array(repeating: "(?, ?, ?)", count: ids.count).joined(separator: ", ")

        // `DatabaseValue` rather than `any DatabaseValueConvertible`: a homogeneous, `Sendable`
        // array, which is both what `StatementArguments`' non-failable initialiser wants and what
        // may be captured by the `@Sendable` body below.
        var values: [DatabaseValue] = []
        values.reserveCapacity(ids.count * 3)
        for id in ids {
            values.append(id.collection.databaseValue)
            values.append(id.number.databaseValue)
            values.append(id.part.databaseValue)
        }
        let arguments = StatementArguments(values)

        let records = try await database.reader().read { database in
            try HadithRecord.fetchAll(
                database,
                sql: """
                    SELECT * FROM hadith
                     WHERE (collection_id, number, part) IN (\(placeholders))
                    """,
                arguments: arguments
            )
        }

        return records.map(\.domainValue)
    }

    // MARK: Search

    func search(_ query: ArabicSearchQuery, limit: Int) async throws -> HadithSearchResults {
        guard !query.isEmpty else { return .none }

        // Two readings of the same words, tried in that order — see `FTS5Query`.
        let expressions = FTS5Query(query)

        return try await database.reader().read { database in
            let search = try expressions.matching { expression in
                try Int.fetchOne(
                    database,
                    sql: "SELECT count(*) FROM hadith_fts WHERE hadith_fts MATCH ?",
                    arguments: [expression]
                ) ?? 0
            }

            // Joined on `hadith.id` rather than on a shared rowid alias, because the index is
            // contentless: `hadith_fts` holds no columns of its own to select from, only the
            // rowids of the narrations it matched.
            let records = try HadithRecord.fetchAll(
                database,
                sql: """
                    SELECT hadith.* FROM hadith_fts
                    JOIN hadith ON hadith.id = hadith_fts.rowid
                    WHERE hadith_fts MATCH ?
                    ORDER BY bm25(hadith_fts)
                    LIMIT ?
                    """,
                arguments: [search.expression, limit]
            )

            return HadithSearchResults(
                hadiths: records.map(\.domainValue),
                total: search.total
            )
        }
    }
}
