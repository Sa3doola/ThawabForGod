//
//  QuranLibraryViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The Library's session (M5.2, design note sections 3.1 to 3.5): the index built once from the reader's
/// corpus, the requested tab resolved against what this build shows, the field's text and what it filters,
/// submit, Continue reading's place, the failure path, surah info's availability, and what is not written.
///
/// Public-build cases open `QuranTestData.publicDatabase` explicitly. Layout cases are guarded with
/// `QuranTestData.hasFullData`, so a public clone skips them with the reason.
@MainActor
struct QuranLibraryViewModelTests {

    // MARK: Helpers

    /// A library over a reader and surah info, both built over the given database and pack store. The
    /// reader's settings write to `store`, so a case can see whether anything was written.
    private static func makeModel(
        repository: any QuranRepositoring = QuranTestData.repository(QuranTestData.publicDatabase),
        packs: any ContentPackStoring = ContentPackStore(directory: nil),
        store: InMemorySettingsStore = InMemorySettingsStore()
    ) -> (library: QuranLibraryViewModel, reader: QuranReaderViewModel, surahInfo: SurahInfoViewModel) {
        let reader = QuranReaderViewModel(
            repository: repository,
            settings: QuranReaderSettings(settingsStore: store),
            allowsImmersive: false
        )
        let surahInfo = SurahInfoViewModel(repository: SurahInfoRepository(store: packs), reader: reader)
        return (QuranLibraryViewModel(reader: reader, surahInfo: surahInfo), reader, surahInfo)
    }

    /// Every key the reader's settings own, read back from the store whatever type it was written as.
    /// The same helper `QuranReaderViewModelTests` uses; kept here because it is private there.
    private static func storedKeys(in store: InMemorySettingsStore) -> Set<SettingsKey> {
        var keys = Set<SettingsKey>()
        for key in QuranReaderSettings.stringKeys where store.string(for: key) != nil { keys.insert(key) }
        for key in QuranReaderSettings.boolKeys where store.bool(for: key) != nil { keys.insert(key) }
        for key in QuranReaderSettings.doubleKeys where store.double(for: key) != nil { keys.insert(key) }
        return keys
    }

    /// The loaded corpus, or a failed expectation. Every case that reads the corpus goes through it.
    private static func loaded(_ reader: QuranReaderViewModel) throws -> QuranCorpus {
        try #require(reader.corpus)
    }

    // MARK: Load and tabs

    @Test func theLoadedPublicLibraryHasThreeTabsAndNoPageTab() async throws {
        let (vm, _, _) = Self.makeModel()
        await vm.load(language: .english)

        guard case .ready = vm.phase else {
            Issue.record("expected .ready, got \(vm.phase)")
            return
        }
        #expect(vm.visibleTabs == [.surah, .juz, .hizb])
        #expect(vm.visibleTabs.count == 3)
        #expect(!vm.showsPages)
        vm.tab = .page
        #expect(vm.tab == .surah, "a request for pages reads back as Surah in a build without them")
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func theLoadedFullLibraryHasFourTabsAndThePageRequestSticks() async throws {
        let (vm, _, _) = Self.makeModel(repository: QuranTestData.repository(QuranTestData.fullDatabase))
        await vm.load(language: .english)

        #expect(vm.visibleTabs == [.surah, .juz, .hizb, .page])
        #expect(vm.showsPages)
        vm.tab = .page
        #expect(vm.tab == .page)
    }

    /// The launch-option path: a request made before the corpus is there is judged once it is.
    @Test func aTabRequestedBeforeTheLoadIsHonouredAfterIt() async throws {
        let (vm, _, _) = Self.makeModel()
        vm.tab = .juz
        #expect(vm.tab == .juz, "before the load the fallback list still holds the juz index")

        await vm.load(language: .english)

        #expect(vm.tab == .juz)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func aPageRequestedBeforeTheLoadIsHonouredInTheFullBuild() async throws {
        let (vm, _, _) = Self.makeModel(repository: QuranTestData.repository(QuranTestData.fullDatabase))
        vm.tab = .page

        await vm.load(language: .english)

        #expect(vm.tab == .page)
    }

    /// Two callers at once (the stack's task and the root's) leave one index, and it is the one the corpus
    /// makes. The index is private, so this reads it through `phase`.
    @Test func twoLoadsAtOnceLeaveOneIndex() async throws {
        let (vm, reader, _) = Self.makeModel()

        async let first: Void = vm.load(language: .english)
        async let second: Void = vm.load(language: .english)
        _ = await (first, second)

        let corpus = try Self.loaded(reader)
        guard case .ready(let index) = vm.phase else {
            Issue.record("expected .ready, got \(vm.phase)")
            return
        }
        #expect(index == QuranLibraryIndex(corpus: corpus))
    }

    // MARK: Typing and the tab

    @Test func aNameTypedOnTheJuzTabMovesToSurah() async throws {
        let (vm, _, _) = Self.makeModel()
        await vm.load(language: .english)
        vm.tab = .juz
        #expect(vm.tab == .juz)

        vm.query = "kahf"

        #expect(vm.tab == .surah)
    }

    /// An address being typed neither filters nor moves the tab, and neither does a number.
    @Test func anAddressOrANumberTypedOnTheJuzTabDoesNotMoveIt() async throws {
        let (vm, _, _) = Self.makeModel()
        await vm.load(language: .english)
        vm.tab = .juz

        vm.query = "juz 5"
        #expect(vm.tab == .juz)
        vm.query = "18"
        #expect(vm.tab == .juz)
        vm.query = "2:255"
        #expect(vm.tab == .juz)
    }

    // MARK: The filter

    @Test func theFilteredSurahsFollowTheQuery() async throws {
        let (vm, reader, _) = Self.makeModel()
        await vm.load(language: .english)
        let corpus = try Self.loaded(reader)

        #expect(vm.filteredSurahs.count == corpus.surahs.count)

        vm.query = "kahf"
        #expect(vm.filteredSurahs.map(\.surah.number) == [18])

        vm.query = "18"
        #expect(vm.filteredSurahs.map(\.surah.number) == [18])

        vm.query = "juz 5"
        #expect(vm.filteredSurahs.count == corpus.surahs.count, "an address narrows nothing")

        vm.query = "zzz"
        #expect(vm.filteredSurahs.isEmpty)
    }

    @Test func theListIsNarrowedOnlyByANumberOrAName() async throws {
        let (vm, _, _) = Self.makeModel()
        await vm.load(language: .english)

        #expect(!vm.isFilteringSurahs)
        vm.query = "18"
        #expect(vm.isFilteringSurahs)
        vm.query = "kahf"
        #expect(vm.isFilteringSurahs)
        vm.query = "juz 5"
        #expect(!vm.isFilteringSurahs)
        vm.query = "2:255"
        #expect(!vm.isFilteringSurahs)
    }

    // MARK: Submit and the field

    @Test func submittingAnAddressGoesAndClearsTheField() async throws {
        let (vm, _, _) = Self.makeModel()
        await vm.load(language: .english)
        vm.query = "juz 5"
        #expect(vm.canSubmit)

        #expect(vm.submit() == .juz(5))
        #expect(vm.query == "")
    }

    @Test func submittingWhatFindsNothingKeepsTheTextAndSaysWhy() async throws {
        let (vm, _, _) = Self.makeModel()
        await vm.load(language: .english)
        vm.query = "zzz"

        #expect(vm.submit() == nil)
        #expect(vm.failure == .notFound)
        #expect(vm.query == "zzz")

        vm.query = "zzzz"
        #expect(vm.failure == nil, "the next edit clears the failure")
    }

    @Test func aBlankFieldCannotBeSubmitted() async throws {
        let (vm, _, _) = Self.makeModel()
        await vm.load(language: .english)
        vm.query = "   "

        #expect(!vm.canSubmit)
        #expect(vm.submit() == nil)
        #expect(vm.failure == nil)
    }

    @Test func didOpenEmptiesTheField() async throws {
        let (vm, reader, _) = Self.makeModel()
        await vm.load(language: .english)
        let corpus = try Self.loaded(reader)
        vm.query = "kahf"

        vm.didOpen()

        #expect(vm.query == "")
        #expect(vm.filteredSurahs.count == corpus.surahs.count)
    }

    // MARK: Continue reading

    @Test func thereIsNoResumePlaceBeforeTheCorpus() throws {
        let (vm, _, _) = Self.makeModel()
        #expect(vm.resume == nil)
    }

    @Test func resumeNamesTheAyahTheReaderIsAtOnThePublicBuild() async throws {
        let (vm, reader, _) = Self.makeModel()
        await vm.load(language: .english)
        let verse = VerseReference(surah: 2, verse: 255)

        reader.open(.ayah(verse))

        let resume = try #require(vm.resume)
        #expect(resume.ayah == verse)
        #expect(resume.surah.number == 2)
        #expect(resume.page == nil, "the public build has no page to name")
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func resumeInMushafModeNamesThePageOnScreen() async throws {
        let (vm, reader, _) = Self.makeModel(repository: QuranTestData.repository(QuranTestData.fullDatabase))
        await vm.load(language: .english)
        reader.setDisplayMode(.mushaf)
        #expect(reader.showsMushafPages)

        reader.open(.ayah(VerseReference(surah: 2, verse: 255)))

        let resume = try #require(vm.resume)
        // The page on screen, not the page of the ayah: that ayah may have started on the one before.
        #expect(resume.page == reader.mushaf.page)
        #expect(resume.ayah == reader.location)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func resumeInSeparatedModeNamesThePageOfTheAyah() async throws {
        let (vm, reader, _) = Self.makeModel(repository: QuranTestData.repository(QuranTestData.fullDatabase))
        await vm.load(language: .english)
        let corpus = try Self.loaded(reader)
        reader.setDisplayMode(.separated)
        let verse = VerseReference(surah: 2, verse: 255)

        reader.open(.ayah(verse))

        let resume = try #require(vm.resume)
        #expect(resume.ayah == verse)
        #expect(resume.page == corpus.pageNumber(for: verse))
    }

    // MARK: Failure and retry

    @Test func aThrowingRepositoryGivesFailedAndRetryRecovers() async throws {
        let repository = CountingQuranRepository()
        await repository.setFailing(true)
        let (vm, reader, _) = Self.makeModel(repository: repository)

        await vm.load(language: .english)
        guard case .failed = vm.phase else {
            Issue.record("expected .failed, got \(vm.phase)")
            return
        }

        await repository.setFailing(false)
        await vm.retry(language: .english)

        guard case .ready = vm.phase else {
            Issue.record("expected .ready after retry, got \(vm.phase)")
            return
        }
        let corpus = try Self.loaded(reader)
        #expect(vm.filteredSurahs.count == corpus.surahs.count)
    }

    // MARK: Surah info

    @Test func aBuildWithOnlyJalalaynOffersNoSurahInfo() async throws {
        let folder = try QuranTestData.packFolder(holding: ["tafsir-ar-jalalayn.sqlite"])
        defer { try? FileManager.default.removeItem(at: folder) }
        let (vm, _, _) = Self.makeModel(packs: ContentPackStore(directory: folder))
        #expect(!vm.hasSurahInfo)

        await vm.load(language: .english)

        #expect(!vm.hasSurahInfo, "a tafsir is not surah info")
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func surahInfoIsOfferedInEnglishAndNotInArabic() async throws {
        let (english, _, _) = Self.makeModel(
            repository: QuranTestData.repository(QuranTestData.fullDatabase),
            packs: QuranTestData.bundledPacks
        )
        await english.load(language: .english)
        #expect(english.hasSurahInfo)

        let (arabic, _, _) = Self.makeModel(
            repository: QuranTestData.repository(QuranTestData.fullDatabase),
            packs: QuranTestData.bundledPacks
        )
        await arabic.load(language: .arabic)
        #expect(!arabic.hasSurahInfo, "there is no Arabic surah info, so no row offers it")
    }

    // MARK: Settings writes

    @Test func theLibraryWritesNoSettingsKey() async throws {
        let store = InMemorySettingsStore()
        let (vm, _, _) = Self.makeModel(store: store)

        await vm.load(language: .english)
        vm.tab = .juz
        vm.query = "kahf"
        vm.query = "juz 5"
        vm.query = "zzz"
        _ = vm.submit()
        vm.query = "juz 5"
        _ = vm.submit()
        vm.query = "kahf"
        vm.didOpen()
        vm.tab = .hizb

        #expect(Self.storedKeys(in: store).isEmpty)
    }
}
