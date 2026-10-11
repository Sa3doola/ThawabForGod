//
//  SurahInfoViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Surah info (M5.2, design note sections 3.6 and 4.2): the facts the screen reads from the corpus, whether a
/// pack exists in the interface language, and the loading phases.
///
/// Mushaf's `englishSurahInfoAndNoArabicYet` ports here, guarded. Its `installed()` assertion is
/// `QuranPackDiscoveryTests`' and is not repeated.
@MainActor
struct SurahInfoViewModelTests {

    // MARK: Doubles and helpers

    /// A reader over one database, loaded or not as the case asks. The screen's facts come from its corpus.
    private static func makeReader(_ database: QuranDatabase) -> QuranReaderViewModel {
        QuranReaderViewModel(
            repository: QuranTestData.repository(database),
            settings: QuranReaderSettings(settingsStore: InMemorySettingsStore()),
            allowsImmersive: false
        )
    }

    // MARK: Facts, public build

    @Test func theFactsOnThePublicBuildHaveNoPages() async throws {
        let reader = Self.makeReader(QuranTestData.publicDatabase)
        let surahInfo = SurahInfoViewModel(
            repository: SurahInfoRepository(store: ContentPackStore(directory: nil)),
            reader: reader
        )
        #expect(surahInfo.facts(for: 2) == nil, "there are no facts before the corpus is loaded")

        await reader.load()

        let corpus = try #require(reader.corpus)
        let facts = try #require(surahInfo.facts(for: 2))
        #expect(facts.surah.number == 2)
        #expect(facts.pages == nil, "the public build has no printed pages to name")
        #expect(facts.startJuz == corpus.ayah(VerseReference(surah: 2, verse: 1))?.juz)
        #expect(surahInfo.facts(for: 115) == nil, "there is no surah 115")
    }

    // MARK: Facts, full build

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func theFactsOnTheFullBuildGiveThePagesFromTheCorpus() async throws {
        let reader = Self.makeReader(QuranTestData.fullDatabase)
        let surahInfo = SurahInfoViewModel(
            repository: SurahInfoRepository(store: ContentPackStore(directory: nil)),
            reader: reader
        )
        await reader.load()
        let corpus = try #require(reader.corpus)

        // Al-Baqarah: from the page its first ayah starts on to the page its last ayah is on, both read
        // from the corpus.
        let baqarah = try #require(corpus.surah(2))
        let baqarahFirst = try #require(baqarah.startPage)
        let baqarahLast = try #require(corpus.pageNumber(for: VerseReference(surah: 2, verse: baqarah.ayahCount)))
        let baqarahFacts = try #require(surahInfo.facts(for: 2))
        #expect(baqarahFacts.pages == baqarahFirst...baqarahLast)
        #expect(baqarahLast > baqarahFirst, "a long surah spans more than one page")

        // An-Nas: a short surah, on one page.
        let nas = try #require(corpus.surah(114))
        let nasFirst = try #require(nas.startPage)
        let nasLast = try #require(corpus.pageNumber(for: VerseReference(surah: 114, verse: nas.ayahCount)))
        let nasFacts = try #require(surahInfo.facts(for: 114))
        #expect(nasFacts.pages == nasFirst...nasLast)
        #expect(nasFacts.pages?.count == 1, "a short surah sits on one page")

        #expect(surahInfo.facts(for: 115) == nil, "there is no surah 115")
    }

    // MARK: Availability and the missing phase

    @Test func withNoPackThereIsNoSurahInfoAndLoadSaysMissing() async throws {
        let surahInfo = SurahInfoViewModel(
            repository: SurahInfoRepository(store: ContentPackStore(directory: nil)),
            reader: Self.makeReader(QuranTestData.publicDatabase)
        )
        #expect(!surahInfo.isAvailable, "nothing is offered before prepare has asked")

        await surahInfo.prepare(language: .english)

        #expect(!surahInfo.isAvailable)
        #expect(surahInfo.pack == nil)
        await surahInfo.load(surah: 2)
        #expect(surahInfo.phase == .missing)
    }

    /// Ported from Mushaf's `englishSurahInfoAndNoArabicYet`, minus the discovery half. The English pack has
    /// an introduction for each surah asked, the Arabic interface has no pack at all, and a tafsir id is not
    /// a surah-info pack.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func theEnglishPackHoldsAnIntroductionForEachSurahAndNoArabicOneExists() async throws {
        let repository = SurahInfoRepository(store: QuranTestData.bundledPacks)

        let arabic = SurahInfoViewModel(repository: repository, reader: Self.makeReader(QuranTestData.publicDatabase))
        await arabic.prepare(language: .arabic)
        #expect(!arabic.isAvailable, "the Arabic interface shows no surah info rather than English text")

        let english = SurahInfoViewModel(repository: repository, reader: Self.makeReader(QuranTestData.publicDatabase))
        await english.prepare(language: .english)
        let pack = try #require(english.pack)
        #expect(pack.language == "en")

        for surah in [1, 2, 9, 114] {
            let info = try #require(try await repository.info(surah: surah, pack: pack.id))
            #expect(!info.summary.isEmpty, "surah \(surah)")

            await english.load(surah: surah)
            guard case .loaded(let content) = english.phase else {
                Issue.record("expected .loaded for surah \(surah), got \(english.phase)")
                return
            }
            #expect(content.surah == surah)
            #expect(!content.document.blocks.isEmpty, "surah \(surah)")
        }

        #expect(try await repository.info(surah: 1, pack: ContentPackID("en-mukhtasar")) == nil, "not a surah-info pack")
    }

    // MARK: Loading

    /// A second request for the surah on screen returns at once: the repository is not asked again.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func loadingTheSameSurahAgainDoesNotReadItAgain() async throws {
        let repository = CountingSurahInfoRepository()
        let surahInfo = SurahInfoViewModel(repository: repository, reader: Self.makeReader(QuranTestData.publicDatabase))
        await surahInfo.prepare(language: .english)

        await surahInfo.load(surah: 1)
        await surahInfo.load(surah: 1)

        let reads = await repository.infoReads
        #expect(reads == 1)
        guard case .loaded(let content) = surahInfo.phase else {
            Issue.record("expected .loaded, got \(surahInfo.phase)")
            return
        }
        #expect(content.surah == 1)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func loadingAnotherSurahReplacesTheContent() async throws {
        let repository = CountingSurahInfoRepository()
        let surahInfo = SurahInfoViewModel(repository: repository, reader: Self.makeReader(QuranTestData.publicDatabase))
        await surahInfo.prepare(language: .english)

        await surahInfo.load(surah: 1)
        await surahInfo.load(surah: 2)

        let reads = await repository.infoReads
        #expect(reads == 2)
        guard case .loaded(let content) = surahInfo.phase else {
            Issue.record("expected .loaded, got \(surahInfo.phase)")
            return
        }
        #expect(content.surah == 2)
        #expect(!content.document.blocks.isEmpty)
    }
}
