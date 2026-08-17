//
//  NamesRepository.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// Serves the ninety-nine names out of the bundled corpus.
///
/// The third feature to read that corpus and, like the second, it needed no change to the
/// infrastructure: `CorpusDatabaseProviding` hands out a reader, this brings its own table and
/// its own SQL, and `AppContainer` passes all three repositories the same `CorpusDatabase`.
///
/// As with the other two, this is the only type in the feature that knows SQL exists, and reads
/// land off the main actor without it arranging anything — GRDB dispatches the body of `read`
/// onto the database's own serial queue whatever actor asked.
nonisolated struct NamesRepository: NamesRepositoring {
    private let database: any CorpusDatabaseProviding

    init(database: any CorpusDatabaseProviding) {
        self.database = database
    }

    func allNames(in language: AppLanguage) async throws -> [DivineName] {
        let records = try await database.reader().read { database in
            try DivineNameRecord.fetchAll(
                database,
                sql: "SELECT * FROM divine_name ORDER BY id"
            )
        }

        // Mapped out here rather than inside the `read`, so the connection is handed back as soon
        // as the rows are in hand and the database queue is never held for view work.
        return records.map { $0.domainValue(in: language) }
    }
}
