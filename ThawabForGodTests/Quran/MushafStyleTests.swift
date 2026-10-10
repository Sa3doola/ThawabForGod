//
//  MushafStyleTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The printed Mushaf layouts the app can show, as data: how many pages and lines, which pages are
/// short, and whether the bundled layout agrees with the definition.
///
/// The definition itself is pure data and runs everywhere. The agreement with the bundled layout
/// needs the printed pages, so it is guarded to the full build (T4). The reader-setting cases
/// (`ReaderSettings.mushafStyle`) are not here: the reader settings are not ported yet.
struct MushafStyleTests {

    @Test func madaniV2() {
        let style = MushafStyle(.madaniV2)
        #expect(style == .madaniV2)
        #expect(style.pageCount == 604)
        #expect(style.linesPerPage == 15)
        #expect(style.shortPages == [1, 2])
        #expect(style.pageAspectRatio == 0.7)
        #expect(style.pages == 1...604)
    }

    @Test func idIsTheDatabaseStyleKey() {
        #expect(MushafStyleID.madaniV2.rawValue == "madaniV2")
        #expect(MushafStyleID.allCases == [.madaniV2])
    }

    /// Whichever database is bundled, the corpus it loads is in the style that was asked for.
    @Test(arguments: [QuranTestData.publicDatabase] + (QuranTestData.hasFullData ? [QuranTestData.fullDatabase] : []))
    func loadedCorpusCarriesItsStyle(_ database: QuranDatabase) async throws {
        let corpus = try await QuranTestData.repository(database).loadCorpus(style: .madaniV2)
        #expect(corpus.style == MushafStyle(.madaniV2))
    }

    /// The style definition must describe the bundled layout exactly.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason), arguments: MushafStyleID.allCases)
    func styleMatchesTheBundledLayout(_ id: MushafStyleID) async throws {
        let style = MushafStyle(id)
        let corpus = try await QuranTestData.repository(QuranTestData.fullDatabase).loadCorpus(style: id)
        #expect(corpus.style == style)
        #expect(corpus.pages.map(\.number) == Array(style.pages))
        #expect(corpus.pages.map(\.lines.count).max() == style.linesPerPage)
        #expect(Set(corpus.pages.filter { $0.lines.count < style.linesPerPage }.map(\.number)) == style.shortPages)
    }
}
