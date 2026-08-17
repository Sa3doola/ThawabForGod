//
//  AdhkarRepository.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// Serves adhkar out of the bundled corpus.
///
/// **The only type in the feature that knows SQL exists.** Everything above it — the use case,
/// the view model, every view — is written against `AdhkarRepositoring` and domain values, which
/// is what lets the whole feature be tested without a database and what would let the corpus
/// move to a different store without a screen noticing.
///
/// Reads run off the main actor without this type arranging anything: GRDB dispatches the body
/// of `read` onto the database's own serial queue and resumes the caller when it returns, so a
/// query cannot land on a frame no matter which actor asked for it. Only `Dhikr` and
/// `AdhkarCategory` — plain `Sendable` values with no tie to the connection they came from —
/// cross back.
nonisolated struct AdhkarRepository: AdhkarRepositoring {
    private let database: any CorpusDatabaseProviding

    init(database: any CorpusDatabaseProviding) {
        self.database = database
    }

    func categories() async throws -> [AdhkarCategory] {
        let identifiers = try await database.reader().read { database in
            try String.fetchAll(database, sql: "SELECT id FROM category ORDER BY sort_order")
        }

        // `compactMap` rather than a force-unwrap: a corpus rebuilt with a category this build
        // of the app has no case for should leave the other categories working, not trap.
        return identifiers.compactMap(AdhkarCategory.init(rawValue:))
    }

    func adhkar(in category: AdhkarCategory, language: AppLanguage) async throws -> [Dhikr] {
        let records = try await database.reader().read { database in
            try DhikrRecord.fetchAll(
                database,
                sql: """
                    SELECT dhikr.*
                    FROM dhikr
                    JOIN dhikr_category ON dhikr_category.dhikr_id = dhikr.id
                    WHERE dhikr_category.category_id = ?
                    ORDER BY dhikr_category.sort_order
                    """,
                arguments: [category.rawValue]
            )
        }

        // Mapped out here rather than inside the `read`, so the connection is handed back as
        // soon as the rows are in hand and the database queue is never held for view work.
        return records.map { $0.domainValue(in: language) }
    }
}
