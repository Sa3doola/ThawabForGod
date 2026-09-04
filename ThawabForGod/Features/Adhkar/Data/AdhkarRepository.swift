//
//  AdhkarRepository.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// Serves Hisn al-Muslim out of the bundled corpus.
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

    /// The chapters, ordered by group first and by the book's own chapter number inside each.
    ///
    /// Ordered here rather than in the view model, because the order is a property of the corpus:
    /// `category_group.sort_order` is the sequence the groups are meant to read in, and the
    /// browse screen only has to cut the list where the group changes.
    func categories() async throws -> [AdhkarCategory] {
        let records = try await database.reader().read { database in
            try AdhkarCategoryRecord.fetchAll(
                database,
                sql: Self.categorySQL(
                    filter: "",
                    order: "ORDER BY category_group.sort_order, category.sort_order"
                )
            )
        }

        // `compactMap` rather than a force-unwrap: a corpus rebuilt with a group this build of
        // the app has no case for should leave the other chapters working, not trap.
        return records.compactMap(\.domainValue)
    }

    func category(id: String) async throws -> AdhkarCategory? {
        let record = try await database.reader().read { database in
            try AdhkarCategoryRecord.fetchOne(
                database,
                sql: Self.categorySQL(filter: "WHERE category.id = ?", order: ""),
                arguments: [id]
            )
        }

        return record?.domainValue
    }

    func adhkar(in category: AdhkarCategory) async throws -> [Dhikr] {
        let records = try await database.reader().read { database in
            try DhikrRecord.fetchAll(
                database,
                sql: """
                    SELECT id, arabic_text, repeat_count
                    FROM dhikr
                    WHERE category_id = ?
                    ORDER BY sort_order
                    """,
                arguments: [category.id]
            )
        }

        // Mapped out here rather than inside the `read`, so the connection is handed back as
        // soon as the rows are in hand and the database queue is never held for view work.
        return records.map(\.domainValue)
    }

    /// The select both category queries share, with the two clauses that differ passed in.
    ///
    /// A function rather than a string the caller appends to, because the clauses go in the
    /// middle: `WHERE` has to precede `GROUP BY` and `ORDER BY` has to follow it, so a template
    /// that ended open could only ever take one of them. Neither argument is ever anything but a
    /// literal written in this file — the id is bound, not interpolated.
    ///
    /// `dhikr_count` is counted rather than stored, so it cannot disagree with the rows the
    /// reading screen will actually be given. A `LEFT JOIN` even though the build refuses to ship
    /// an empty chapter: a `JOIN` would make an empty one *vanish*, which is a corpus fault
    /// showing up as a missing row rather than as a visible zero.
    private static func categorySQL(filter: String, order: String) -> String {
        """
        SELECT category.id,
               category.title_ar,
               category.title_en,
               category.group_id,
               category.sort_order,
               count(dhikr.id) AS dhikr_count
        FROM category
        JOIN category_group ON category_group.id = category.group_id
        LEFT JOIN dhikr ON dhikr.category_id = category.id
        \(filter)
        GROUP BY category.id
        \(order)
        """
    }
}
