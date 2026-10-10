//
//  QuranDatabase.swift
//  ThawabForGod
//

import Foundation

/// Which Quran database the app has, opened through the corpus infrastructure every other
/// read-only file uses.
///
/// **The full build when it is bundled, the public one otherwise** (T4). `quran-mushaf.sqlite` is
/// the `qul` profile's — the printed Madani V2 pages, built locally and git-ignored — and
/// `quran.sqlite` is the committed `tanzil` profile's. Both are one schema; what the app may offer
/// is read from the chosen file's `meta.capabilities`, never inferred from which one this picked.
///
/// Mushaf's own `QuranDatabase` actor kept a lazy queue of its own; here that is `CorpusDatabase`'s
/// job, so the Quran, its search and the packs' ayah index share one reader.
nonisolated struct QuranDatabase: Sendable {
    /// The `qul` profile's output, preferred when present.
    static let fullResourceName = "quran-mushaf"
    /// The `tanzil` profile's output, in every clone.
    static let publicResourceName = "quran"

    /// The resource that was chosen, without its extension.
    let resourceName: String
    let corpus: any CorpusDatabaseProviding

    init(resourceName: String, corpus: any CorpusDatabaseProviding) {
        self.resourceName = resourceName
        self.corpus = corpus
    }

    /// The preferred database in `bundle`: the full one if it was bundled, else the public one.
    static func bundled(in bundle: Bundle = .main) -> QuranDatabase {
        let name = bundle.url(forResource: fullResourceName, withExtension: "sqlite") != nil
            ? fullResourceName
            : publicResourceName
        return QuranDatabase(resourceName: name, corpus: CorpusDatabase(name: name, bundle: bundle))
    }
}
