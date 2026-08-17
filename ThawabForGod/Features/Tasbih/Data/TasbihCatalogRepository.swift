//
//  TasbihCatalogRepository.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// Serves the tasbih presets out of the bundled corpus.
///
/// The second feature to read that corpus, and it needed no change to the infrastructure to do
/// it: `CorpusDatabaseProviding` hands out a reader, this brings its own table and its own SQL,
/// and `AppContainer` passes both repositories the same `CorpusDatabase`, so one file is opened
/// however many features come to depend on it.
///
/// As with `AdhkarRepository`, this is the only type in the feature that knows SQL exists, and
/// reads land off the main actor without it arranging anything — GRDB dispatches the body of
/// `read` onto the database's own serial queue whatever actor asked.
nonisolated struct TasbihCatalogRepository: TasbihCatalogProviding {
    private let database: any CorpusDatabaseProviding

    init(database: any CorpusDatabaseProviding) {
        self.database = database
    }

    func presets(in language: AppLanguage) async throws -> [TasbihDhikr] {
        let records = try await database.reader().read { database in
            try TasbihPresetRecord.fetchAll(
                database,
                sql: "SELECT * FROM tasbih_preset ORDER BY sort_order"
            )
        }

        // Mapped out here rather than inside the `read`, so the connection is handed back as soon
        // as the rows are in hand and the database queue is never held for view work.
        return records.map { $0.domainValue(in: language) }
    }
}
