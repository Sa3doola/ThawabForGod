//
//  QuranTestData.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The Quran databases and packs the suites read, and the one question that decides which tests
/// can run: was the full data built here?
///
/// **Two builds** (T4). `quran.sqlite` and the Jalalayn pack are committed, so every clone has
/// them. `quran-mushaf.sqlite`, the four QUL packs and the QUL faces exist only where
/// `Tools/QuranBuilder --profile qul` was run, since QUL publishes no licence and they are
/// git-ignored. A test that needs the printed layout or a QUL pack is *guarded*:
///
///     @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
///
/// so a public clone skips it with the reason rather than failing it.
nonisolated enum QuranTestData {

    /// Whether the full (QUL) data is bundled.
    static let hasFullData = Bundle.main.url(forResource: QuranDatabase.fullResourceName, withExtension: "sqlite") != nil

    /// Why a guarded test was skipped.
    static let fullDataReason: Comment = "needs the full Quran data: swift run -c release --package-path Tools/QuranBuilder QuranBuilder --profile qul"

    /// The full database, whatever the app would prefer. Only open it behind the guard.
    static let fullDatabase = QuranDatabase(
        resourceName: QuranDatabase.fullResourceName,
        corpus: CorpusDatabase(name: QuranDatabase.fullResourceName)
    )

    /// The public (Tanzil) database, in every clone.
    static let publicDatabase = QuranDatabase(
        resourceName: QuranDatabase.publicResourceName,
        corpus: CorpusDatabase(name: QuranDatabase.publicResourceName)
    )

    /// What the app opens: the full database when bundled, else the public one.
    static let preferredDatabase = QuranDatabase.bundled()

    static func repository(_ database: QuranDatabase = preferredDatabase) -> QuranRepository {
        QuranRepository(database: database.corpus)
    }

    static func index(_ database: QuranDatabase = preferredDatabase) -> QuranAyahIndex {
        QuranAyahIndex(database: database.corpus)
    }
}
