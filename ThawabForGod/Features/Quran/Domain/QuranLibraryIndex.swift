//
//  QuranLibraryIndex.swift
//  ThawabForGod
//

import Foundation

/// Which index the Library shows.
///
/// A value rather than a view's state because it is also a launch option's raw value
/// (`-quranLibrary page`), and because a request for a tab this build does not have is judged
/// against `QuranLibraryIndex.tabs`, not here.
nonisolated enum QuranLibraryTab: String, CaseIterable, Identifiable, Sendable {
    case surah, juz, hizb, page

    var id: Self { self }
}

/// One surah in the Library's first index.
nonisolated struct QuranLibrarySurahRow: Identifiable, Hashable, Sendable {
    let surah: Surah
    /// `nil` in a build without the printed pages.
    let startPage: Int?
    /// The English name as lower-case ASCII letters, and the Arabic name folded for search. Built
    /// once, so a keystroke folds the query and runs 114 `contains`, never 114 normalisations.
    let latinKey: String
    let arabicKey: String

    var id: Int { surah.number }
}

/// A juz, a hizb or one of a hizb's three later quarters: all of them are "an ayah where a
/// division begins", which is why they share a row model.
nonisolated struct QuranLibraryStartRow: Identifiable, Hashable, Sendable {
    nonisolated enum Kind: Hashable, Sendable {
        case juz, hizb
        /// 1, 2 or 3: the quarter, half and three-quarter marks after the hizb's own start.
        case quarter(Int)
    }

    let kind: Kind
    /// The juz or hizb number; for a quarter, the hizb it belongs to.
    let number: Int
    let ayah: VerseReference
    /// The start ayah's surah, for its name.
    let surah: Surah
    /// `nil` in a build without the printed pages.
    let page: Int?
    /// `.juz(n)`, `.hizb(n)`, or `.ayah(start)` for a quarter: Mushaf sends a quarter to its ayah,
    /// not to its hizb.
    let target: GoToTarget
    /// "juz.5", "hizb.12", "quarter.46" (the rub number). Also the accessibility identifier's suffix.
    let id: String
}

nonisolated struct QuranLibraryHizbRow: Identifiable, Hashable, Sendable {
    let hizb: QuranLibraryStartRow
    let quarters: [QuranLibraryStartRow]

    var id: String { hizb.id }
}

nonisolated struct QuranLibraryPageCell: Identifiable, Hashable, Sendable {
    let number: Int
    /// The surah of the page's first ayah.
    let surah: Surah?

    var id: Int { number }
}

/// The Library's four indexes as row models, and the one place that decides what this build's
/// Library shows (Q5): which tabs exist, and whether any row carries a page number.
///
/// The gate is the build's capability (`QuranCorpus.hasPages`), not whether a column happens to be
/// empty, so a public database that one day carried Tanzil's page table would still show no page
/// number: every page below goes through `init`'s one helper.
nonisolated struct QuranLibraryIndex: Equatable, Sendable {
    let showsPages: Bool
    let surahs: [QuranLibrarySurahRow]
    let juz: [QuranLibraryStartRow]
    let hizb: [QuranLibraryHizbRow]
    /// Empty where `showsPages` is false.
    let pages: [QuranLibraryPageCell]

    var tabs: [QuranLibraryTab] { Self.tabs(showingPages: showsPages) }

    /// No Page tab where there are no printed pages.
    static func tabs(showingPages: Bool) -> [QuranLibraryTab] {
        showingPages ? [.surah, .juz, .hizb, .page] : [.surah, .juz, .hizb]
    }

    /// Pure and synchronous: for tests.
    init(corpus: QuranCorpus) {
        let showsPages = corpus.hasPages
        self.showsPages = showsPages

        /// The only place a page number passes into a row.
        func gated(_ page: Int?) -> Int? { showsPages ? page : nil }

        surahs = corpus.surahs.map { surah in
            QuranLibrarySurahRow(
                surah: surah,
                startPage: gated(surah.startPage),
                latinKey: QuranGoTo.latinKey(surah.englishName),
                arabicKey: QuranGoTo.arabicKey(surah.arabicName)
            )
        }

        func row(_ kind: QuranLibraryStartRow.Kind, number: Int, start: QuranMetadata.Start,
                 id: String, target: GoToTarget) -> QuranLibraryStartRow? {
            guard let surah = corpus.surah(start.ayah.surah) else { return nil }
            return QuranLibraryStartRow(
                kind: kind, number: number, ayah: start.ayah, surah: surah,
                page: gated(start.page), target: target, id: id
            )
        }

        juz = corpus.metadata.juz.compactMap {
            row(.juz, number: $0.number, start: $0, id: "juz.\($0.number)", target: .juz($0.number))
        }

        // One pass over the 240 quarters, grouped by the hizb they sit in.
        var quartersByHizb: [Int: [QuranLibraryStartRow]] = [:]
        for rub in corpus.metadata.rub where (rub.number - 1) % 4 != 0 {
            let hizbNumber = (rub.number - 1) / 4 + 1
            if let quarter = row(.quarter((rub.number - 1) % 4), number: hizbNumber, start: rub,
                                 id: "quarter.\(rub.number)", target: .ayah(rub.ayah)) {
                quartersByHizb[hizbNumber, default: []].append(quarter)
            }
        }
        hizb = corpus.metadata.hizb.compactMap { start in
            row(.hizb, number: start.number, start: start, id: "hizb.\(start.number)", target: .hizb(start.number))
                .map { QuranLibraryHizbRow(hizb: $0, quarters: quartersByHizb[start.number] ?? []) }
        }

        pages = showsPages
            ? corpus.pages.map { page in
                QuranLibraryPageCell(number: page.number, surah: page.firstAyah.flatMap { corpus.surah($0.surah) })
            }
            : []
    }

    /// The same, off the main actor: 114 names folded, 240 quarters grouped, 604 pages walked.
    @concurrent static func make(from corpus: QuranCorpus) async -> QuranLibraryIndex {
        QuranLibraryIndex(corpus: corpus)
    }
}
