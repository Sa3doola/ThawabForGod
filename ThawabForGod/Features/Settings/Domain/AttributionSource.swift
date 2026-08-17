//
//  AttributionSource.swift
//  ThawabForGod
//

import Foundation

/// One bundled data set or dependency, and where it came from.
///
/// The app ships other people's work — an MIT-licensed adhkar collection, two libraries, a list
/// of the divine names compiled from public sources — and saying so in the app rather than only
/// in a repository README is part of using it. This is that list, as data.
///
/// Everything user-facing is an `L10nKey`, including the lines that are mostly proper nouns:
/// a translator may well want to write "سين العربية" where English writes "Seen Arabic", and a
/// hardcoded string would take that decision away from them.
nonisolated struct AttributionSource: Identifiable, Sendable {
    let id: String

    /// What the data set is, in the app's own terms — "Morning & Evening Adhkar".
    let titleKey: L10nKey

    /// Who made it, and the name it goes by upstream.
    let attributionKey: L10nKey

    /// The licence it is used under, or the fact that the position is unsettled.
    let licenceKey: L10nKey

    /// A caveat the reader is entitled to before trusting the content — that the text has not
    /// been checked by a scholar, that a translation is one reading among several. `nil` where
    /// there is nothing to warn about.
    let noteKey: L10nKey?

    /// Where it can be read in full. Optional because the tasbih presets have no upstream.
    let url: URL?
}

nonisolated extension AttributionSource {
    /// Every source the app ships, in the order a reader is likely to care about: the religious
    /// content first, the libraries after.
    ///
    /// The two unverified notes here are not placeholders — they are the standing warnings from
    /// `Resources/Corpus/README.md`, which says in as many words that neither the adhkar text nor
    /// the English meanings of the divine names may ship as verified in V1. Surfacing them is how
    /// the app stops making a claim it cannot support.
    ///
    /// `URL(string:)!` is force-unwrapped on purpose: these are literals in this file, so a nil
    /// is a typo made by whoever edits it and belongs at the top of the first launch, not in a
    /// silently empty row.
    static let all: [AttributionSource] = [
        AttributionSource(
            id: "adhkar",
            titleKey: .sourceAdhkarTitle,
            attributionKey: .sourceAdhkarAttribution,
            licenceKey: .licenceMIT,
            noteKey: .sourceAdhkarNote,
            url: URL(string: "https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB")!
        ),
        AttributionSource(
            id: "names",
            titleKey: .sourceNamesTitle,
            attributionKey: .sourceNamesAttribution,
            licenceKey: .licenceUnsettled,
            noteKey: .sourceNamesNote,
            url: URL(string: "https://github.com/KabDeveloper/99-Names-Of-Allah")!
        ),
        AttributionSource(
            id: "tasbih",
            titleKey: .sourceTasbihTitle,
            attributionKey: .sourceTasbihAttribution,
            licenceKey: .licenceNone,
            noteKey: nil,
            url: nil
        ),
        AttributionSource(
            id: "adhan",
            titleKey: .sourceAdhanTitle,
            attributionKey: .sourceAdhanAttribution,
            licenceKey: .licenceMIT,
            noteKey: nil,
            url: URL(string: "https://github.com/batoulapps/adhan-swift")!
        ),
        AttributionSource(
            id: "grdb",
            titleKey: .sourceGRDBTitle,
            attributionKey: .sourceGRDBAttribution,
            licenceKey: .licenceMIT,
            noteKey: nil,
            url: URL(string: "https://github.com/groue/GRDB.swift")!
        )
    ]
}
