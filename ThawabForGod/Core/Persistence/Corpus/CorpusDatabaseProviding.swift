//
//  CorpusDatabaseProviding.swift
//  ThawabForGod
//

import GRDB

/// Access to the bundled, read-only reference corpus.
///
/// The corpus is the app's *unchanging* content — adhkar today; the 99 Names, tasbih and the
/// Quran later. It is deliberately a different store from `Core/Persistence`'s SwiftData
/// container, which holds only what the user changes. Read-only data has no migrations, no
/// conflicts and no schema evolution at runtime, so paying SwiftData's costs for it would buy
/// nothing.
///
/// **This protocol is infrastructure, not Domain.** It names a GRDB type, so only Data-layer
/// repositories may depend on it — `AdhkarRepositoring` and everything above it speak in domain
/// entities and never learn that SQLite exists. That is the seam that keeps GRDB swappable and
/// lets every use case and view model be tested without a database at all.
nonisolated protocol CorpusDatabaseProviding: Sendable {

    /// The shared reader for the corpus, opening it on first use.
    ///
    /// Throws rather than trapping: a database missing from the bundle is a packaging mistake,
    /// and it should cost the reader one feature with an explicable error on it, not the whole
    /// app on launch.
    func reader() throws -> any DatabaseReader
}

/// What can go wrong reaching the corpus, before any query has run.
nonisolated enum CorpusDatabaseError: Error, Equatable {

    /// The database is not in the bundle — the resource was renamed, or never copied.
    case resourceMissing(name: String)
}
