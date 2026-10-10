//
//  QuranCapabilitiesTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// What each build says it can do, and what the repository does with a build that cannot.
///
/// The app hides Mushaf mode and the Library's Page tab by asking `supportsMushafPages` (T4, Q5),
/// so the answer has to come from the file itself — and a page number the fallback cannot know has
/// to be `nil`, never a page of a different print (T4: Tanzil's page breaks differ from V2 for 56
/// verses).
struct QuranCapabilitiesTests {

    // MARK: Parsing

    @Test func theMetaListParsesIntoCapabilities() {
        #expect(QuranCapabilities(meta: "text") == .text)
        #expect(QuranCapabilities(meta: "text,words,mushafPages,glyphV2,fontLigatures")
                == [.text, .words, .mushafPages, .glyphV2, .fontLigatures])
        #expect(QuranCapabilities(meta: " text , mushafPages ").supportsMushafPages)
    }

    /// A database from a newer builder still opens on what this build knows.
    @Test func anUnknownCapabilityIsIgnored() {
        #expect(QuranCapabilities(meta: "text,somethingNew") == .text)
        #expect(QuranCapabilities(meta: "").isEmpty)
    }

    // MARK: Each database

    @Test func thePublicDatabaseCarriesTextAlone() async throws {
        let capabilities = try await QuranTestData.repository(QuranTestData.publicDatabase).capabilities()

        #expect(capabilities == .text)
        #expect(!capabilities.supportsMushafPages)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func theFullDatabaseCarriesThePrintedMushaf() async throws {
        let capabilities = try await QuranTestData.repository(QuranTestData.fullDatabase).capabilities()

        #expect(capabilities == [.text, .words, .mushafPages, .glyphV2, .fontLigatures])
        #expect(capabilities.supportsMushafPages)
    }

    /// The app opens the full database where it was built, the public one everywhere else.
    @Test func theAppPrefersTheFullDatabaseWhenItIsBundled() {
        #expect(QuranDatabase.bundled().resourceName
                == (QuranTestData.hasFullData ? QuranDatabase.fullResourceName : QuranDatabase.publicResourceName))
    }

    // MARK: The fallback, read through the repository

    @Test func theFallbackCorpusHasTheTextAndNoPages() async throws {
        let corpus = try await QuranTestData.repository(QuranTestData.publicDatabase).loadCorpus(style: .madaniV2)

        #expect(corpus.surahs.count == 114)
        #expect(corpus.ayahs.count == 6236)
        #expect(!corpus.hasPages)
        #expect(corpus.surahs.allSatisfy { $0.startPage == nil })
        #expect(corpus.ayahs.allSatisfy { $0.page == nil })
        #expect(corpus.pageNumber(for: VerseReference(surah: 2, verse: 255)) == nil)
        #expect(corpus.ayah(VerseReference(surah: 2, verse: 1))?.text == "الٓمٓ")
    }

    /// The divisions are the text's, so the fallback keeps the Library's Juz and Hizb tabs (Q5):
    /// every start is there, at the ayah Tanzil places it, with no page.
    @Test func theFallbackStillKnowsWhereEveryDivisionBegins() async throws {
        let metadata = try await QuranTestData.repository(QuranTestData.publicDatabase).metadata(style: .madaniV2)

        #expect(metadata.juz.map(\.number) == Array(1...30))
        #expect(metadata.hizb.map(\.number) == Array(1...60))
        #expect(metadata.rub.map(\.number) == Array(1...240))
        #expect(metadata.sajdahs.count == 15)
        #expect(metadata.sajdahs.filter(\.isRequired).count == 4)
        #expect(metadata.juz[1].ayah == VerseReference(surah: 2, verse: 142))
        #expect(metadata.juz.allSatisfy { $0.page == nil } && metadata.sajdahs.allSatisfy { $0.page == nil })
    }

    @Test func theFallbackRefusesToNameAPage() async throws {
        let repository = QuranTestData.repository(QuranTestData.publicDatabase)

        await #expect(throws: QuranDataError.unsupported(.mushafPages)) {
            try await repository.page(1, style: .madaniV2)
        }
        await #expect(throws: QuranDataError.unsupported(.mushafPages)) {
            try await repository.pageNumber(for: VerseReference(surah: 2, verse: 255), style: .madaniV2)
        }
        #expect(try await repository.surahs(style: .madaniV2).allSatisfy { $0.startPage == nil })
        #expect(try await repository.ayahs(surah: 18, style: .madaniV2).allSatisfy { $0.page == nil })
    }

    /// The fallback has no `word` rows, so it writes each end marker out; the full build stores
    /// them. They must be the same characters, or a verse would end differently by build.
    @Test func theFallbackWritesTheEndMarkerTheFullBuildStores() async throws {
        let ayahs = try await QuranTestData.repository(QuranTestData.publicDatabase).ayahs(surah: 2, style: .madaniV2)

        #expect(ayahs.count == 286)
        #expect(ayahs.first { $0.id.verse == 255 }?.marker == "٢٥٥")
        #expect(ayahs.first?.marker == "١")
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func everyEndMarkerAgreesBetweenTheBuilds() async throws {
        let fallback = try await QuranTestData.repository(QuranTestData.publicDatabase).loadCorpus(style: .madaniV2)
        let full = try await QuranTestData.repository(QuranTestData.fullDatabase).loadCorpus(style: .madaniV2)

        let differing = zip(fallback.ayahs, full.ayahs).filter { $0.0.id != $0.1.id || $0.0.marker != $0.1.marker }
        #expect(fallback.ayahs.count == full.ayahs.count)
        #expect(differing.isEmpty, "differs at \(differing.prefix(3).map(\.0.id))")
    }

    /// The two builds number the ayahs the same way, which is what lets a pack built against
    /// either be read with either (`QuranAyahIndex`).
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func bothBuildsNumberTheAyahsAlike() throws {
        let fallback = QuranTestData.index(QuranTestData.publicDatabase)
        let full = QuranTestData.index(QuranTestData.fullDatabase)

        for id in [1, 7, 8, 262, 6236] {
            #expect(try fallback.reference(of: id) == full.reference(of: id))
        }
        #expect(try fallback.reference(of: 262) == VerseReference(surah: 2, verse: 255))
        #expect(try fallback.ids(inSurah: 2) == 8...293)
    }
}
