//
//  QuranReaderViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The reader's session (M5.1, design note sections 3.2 to 3.3 and 4.7): the one corpus load, the
/// target parked until it arrives, the reading place in both modes, the switch between them, the
/// immersive question, and what is and is not written to settings.
///
/// Mushaf's `AppRouterTests` cases `selectingAnAyahNoLongerPresentsFromTheModel` and
/// `emptyEnvironmentHasNoData` port here: the first as `select` with no corpus, the second as the
/// failed load.
///
/// The stub is an `actor`, so the counting and the failure switch are its own state and the protocol's
/// `@concurrent` requirements are satisfied the way `StubAdhkarRepository` satisfies them. Its success
/// path delegates to the real repository over the public database.
@MainActor
struct QuranReaderViewModelTests {

    // MARK: Doubles and helpers

    /// Every key the reader's settings own, read back from the store whatever type it was written as.
    /// The same helper `QuranReaderSettingsTests` uses; kept here because it is private there.
    private static func storedKeys(in store: InMemorySettingsStore) -> Set<SettingsKey> {
        var keys = Set<SettingsKey>()
        for key in QuranReaderSettings.stringKeys where store.string(for: key) != nil { keys.insert(key) }
        for key in QuranReaderSettings.boolKeys where store.bool(for: key) != nil { keys.insert(key) }
        for key in QuranReaderSettings.doubleKeys where store.double(for: key) != nil { keys.insert(key) }
        return keys
    }

    private static func makeModel(
        repository: any QuranRepositoring = QuranTestData.repository(QuranTestData.publicDatabase),
        store: InMemorySettingsStore = InMemorySettingsStore(),
        allowsImmersive: Bool = true
    ) -> (model: QuranReaderViewModel, settings: QuranReaderSettings, store: InMemorySettingsStore) {
        let settings = QuranReaderSettings(settingsStore: store)
        let model = QuranReaderViewModel(
            repository: repository,
            settings: settings,
            allowsImmersive: allowsImmersive
        )
        return (model, settings, store)
    }

    /// The loaded corpus, or a failed expectation. Every test that reads the corpus goes through it.
    private static func loaded(_ model: QuranReaderViewModel) throws -> QuranCorpus {
        try #require(model.corpus)
    }

    // MARK: Load

    @Test func twoConcurrentLoadsReadTheCorpusOnce() async throws {
        let repository = CountingQuranRepository()
        let (model, _, _) = Self.makeModel(repository: repository)

        async let first: Void = model.load()
        async let second: Void = model.load()
        _ = await (first, second)

        let corpusReads = await repository.corpusReads
        let capabilityReads = await repository.capabilityReads
        #expect(model.corpus != nil)
        #expect(corpusReads == 1)
        #expect(capabilityReads == 1)
    }

    @Test func aLoadAfterTheCorpusIsReadyReadsNothingAgain() async throws {
        let repository = CountingQuranRepository()
        let (model, _, _) = Self.makeModel(repository: repository)

        await model.load()
        await model.load()

        let corpusReads = await repository.corpusReads
        #expect(corpusReads == 1)
    }

    @Test func aThrowingRepositoryGivesTheFailedPhaseAndRetryRecovers() async throws {
        let repository = CountingQuranRepository()
        await repository.setFailing(true)
        let (model, _, _) = Self.makeModel(repository: repository)

        await model.load()
        guard case .failed = model.phase else {
            Issue.record("expected .failed, got \(model.phase)")
            return
        }
        #expect(model.corpus == nil)

        await repository.setFailing(false)
        await model.retry()

        guard case .ready = model.phase else {
            Issue.record("expected .ready after retry, got \(model.phase)")
            return
        }
        #expect(model.corpus != nil)
    }

    /// Ported from Mushaf's `emptyEnvironmentHasNoData`: with no data the load fails, and the reader
    /// has no corpus to show.
    @Test func emptyEnvironmentHasNoData() async throws {
        let repository = CountingQuranRepository()
        await repository.setFailing(true)
        let (model, _, _) = Self.makeModel(repository: repository)

        await model.load()

        guard case .failed = model.phase else {
            Issue.record("expected .failed, got \(model.phase)")
            return
        }
        #expect(model.corpus == nil)
        #expect(!model.showsMushafPages)
        #expect(!model.canSwitchDisplayMode)
    }

    // MARK: Parked targets

    @Test func aTargetOpenedBeforeTheLoadIsAppliedAfterIt() async throws {
        let (model, _, _) = Self.makeModel()

        model.open(.surah(2))
        #expect(model.separatedSurah == 1, "nothing moves before the corpus is there")

        await model.load()

        #expect(model.separatedSurah == 2)
    }

    @Test func theLatestOfTwoParkedTargetsWins() async throws {
        let (model, _, _) = Self.makeModel()

        model.open(.surah(3))
        model.open(.surah(2))
        await model.load()

        #expect(model.separatedSurah == 2)
    }

    // MARK: Public database: no modes to switch

    @Test func thePublicDatabaseCannotSwitchModesAndNeverShowsPages() async throws {
        let (model, settings, _) = Self.makeModel()
        await model.load()

        #expect(!model.canSwitchDisplayMode)
        #expect(!model.showsMushafPages)
        #expect(settings.availableDisplayModes == [.separated])
    }

    @Test func askingForMushafInThePublicBuildMovesNothingAndWritesNoKey() async throws {
        let (model, _, store) = Self.makeModel()
        await model.load()
        let pageBefore = model.mushaf.page
        let surahBefore = model.separatedSurah

        model.setDisplayMode(.mushaf)

        #expect(model.mushaf.page == pageBefore)
        #expect(model.separatedSurah == surahBefore)
        #expect(!model.showsMushafPages)
        #expect(Self.storedKeys(in: store).isEmpty, "a mode the build cannot show is refused before anything is stored")
    }

    @Test func aStoredMushafChoiceStillShowsSeparatedInThePublicBuild() async throws {
        let store = InMemorySettingsStore(strings: [.quranDisplayMode: QuranDisplayMode.mushaf.rawValue])
        let (model, settings, _) = Self.makeModel(store: store)
        await model.load()

        #expect(settings.displayMode == .separated)
        #expect(!model.showsMushafPages)
        #expect(store.string(for: .quranDisplayMode) == QuranDisplayMode.mushaf.rawValue, "the stored choice is kept, not overwritten")
    }

    @Test func aPageTargetMovesNothingInThePublicBuild() async throws {
        let (model, _, _) = Self.makeModel()
        await model.load()
        let pageBefore = model.mushaf.page
        let surahBefore = model.separatedSurah
        let locationBefore = model.location

        model.open(.page(50))

        #expect(model.mushaf.page == pageBefore)
        #expect(model.separatedSurah == surahBefore)
        #expect(model.location == locationBefore)
        #expect(model.separatedScrollRequest == nil)
    }

    // MARK: Capabilities agree with the corpus

    @Test(arguments: [QuranTestData.publicDatabase] + (QuranTestData.hasFullData ? [QuranTestData.fullDatabase] : []))
    func theCapabilitiesAgreeWithTheCorpusOnWhetherPagesExist(_ database: QuranDatabase) async throws {
        let (model, settings, _) = Self.makeModel(repository: QuranTestData.repository(database))
        await model.load()
        let corpus = try Self.loaded(model)

        #expect(settings.capabilities.supportsMushafPages == corpus.hasPages)
        #expect(model.canSwitchDisplayMode == corpus.hasPages)
    }

    // MARK: Full data: the switch in both directions

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func separatedToMushafShowsThePageHoldingTheFirstAyahInView() async throws {
        let (model, _, _) = Self.makeModel(repository: QuranTestData.repository(QuranTestData.fullDatabase))
        await model.load()
        let corpus = try Self.loaded(model)
        let verse = VerseReference(surah: 2, verse: 255)
        let openedPage = try #require(corpus.pageNumber(for: verse))

        model.setDisplayMode(.separated)
        model.open(.ayah(verse))
        #expect(model.separatedLocation == verse)
        // `open` shows the page of the ayah it was given. The list then scrolls: its top ayah moves
        // on, and the page on screen must not, because nothing has asked for a page turn.
        #expect(model.mushaf.page == openedPage)

        // An ayah several pages on, in the same surah, read from the corpus.
        let scrolledTo = try #require(corpus.page(openedPage + 5)?.firstAyah)
        #expect(scrolledTo.surah == verse.surah, "the moved-to ayah is in the same surah")
        let scrolledPage = try #require(corpus.pageNumber(for: scrolledTo))
        #expect(scrolledPage != openedPage, "the moved-to ayah must sit on a different page")
        model.separatedTopAyahDidChange(scrolledTo)
        #expect(model.separatedLocation == scrolledTo)
        #expect(model.mushaf.page == openedPage, "scrolling the list must not turn the page")

        model.setDisplayMode(.mushaf)

        #expect(model.showsMushafPages)
        #expect(model.mushaf.page == scrolledPage)
    }

    /// Page 201 falls inside surah 9, so its first ayah is not the surah's opening (checked below),
    /// and a separated reader that lost the place would open at 9:1 rather than here.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func mushafToSeparatedShowsThePagesFirstAyahAndBackLandsOnThePage() async throws {
        let (model, _, _) = Self.makeModel(repository: QuranTestData.repository(QuranTestData.fullDatabase))
        await model.load()
        let corpus = try Self.loaded(model)
        let page = 201
        let firstAyah = try #require(corpus.page(page)?.firstAyah)
        #expect(firstAyah.surah == 9, "page \(page) is read as inside surah 9")
        #expect(firstAyah.verse != 1, "page \(page) must begin inside its surah for this case to mean anything")

        // Hold surah 9 with the list somewhere else in it, as a reader who scrolled would.
        model.open(.ayah(VerseReference(surah: 9, verse: 1)))
        let elsewhere = VerseReference(surah: 9, verse: 2)
        model.separatedTopAyahDidChange(elsewhere)
        #expect(model.separatedSurah == 9)
        #expect(model.separatedLocation == elsewhere)

        // The reader turns to a page in the middle of that surah, in Mushaf mode.
        model.mushaf.show(page: page)
        #expect(model.mushaf.page == page)

        model.setDisplayMode(.separated)

        #expect(model.separatedSurah == firstAyah.surah, "the surah is the one already held")
        #expect(model.separatedLocation == firstAyah, "the list opens at the page's first ayah, not where it was")

        model.setDisplayMode(.mushaf)

        #expect(model.mushaf.page == page)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func theCapabilitiesMatchTheFullCorpusWithPages() async throws {
        let (model, settings, _) = Self.makeModel(repository: QuranTestData.repository(QuranTestData.fullDatabase))
        await model.load()
        let corpus = try Self.loaded(model)

        #expect(settings.capabilities.supportsMushafPages)
        #expect(corpus.hasPages)
        #expect(model.canSwitchDisplayMode)
    }

    /// The case the view broke on: the surah does not change, so nothing rebuilds the list, and the
    /// place must still come across.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func mushafToSeparatedWithinOneSurahKeepsThePlace() async throws {
        let (model, _, _) = Self.makeModel(repository: QuranTestData.repository(QuranTestData.fullDatabase))
        await model.load()
        let corpus = try Self.loaded(model)

        model.open(.surah(2))
        #expect(model.separatedSurah == 2)
        // A page further on in surah 2, read from the corpus: its first ayah is in surah 2 and is not 2:1.
        let target = try #require(corpus.page(20)?.firstAyah)
        #expect(target.surah == 2 && target.verse != 1)
        model.mushaf.show(page: 20)

        model.setDisplayMode(.separated)

        #expect(model.separatedSurah == 2, "the surah is unchanged")
        #expect(model.separatedLocation == target)
        #expect(model.separatedScrollRequest == nil, "a surah change does not ask for a scroll")
    }

    /// Reopening the surah already held goes to its top, not to where the list was left.
    @Test func reopeningTheSurahAlreadyHeldGoesToItsTop() async throws {
        let (model, _, _) = Self.makeModel()
        await model.load()

        model.open(.surah(2))
        model.separatedTopAyahDidChange(VerseReference(surah: 2, verse: 40))
        #expect(model.separatedLocation == VerseReference(surah: 2, verse: 40))

        model.open(.surah(2))

        #expect(model.separatedSurah == 2)
        #expect(model.separatedLocation == VerseReference(surah: 2, verse: 1))
        let first = try #require(model.separatedScrollRequest)
        #expect(first.ayah == VerseReference(surah: 2, verse: 1))

        model.open(.surah(2))
        let second = try #require(model.separatedScrollRequest)
        #expect(second.ayah == VerseReference(surah: 2, verse: 1))
        #expect(first != second, "each reopening is a new request")
    }

    /// Reopening an ayah in the surah already held selects it and scrolls to it, from wherever the
    /// list was left.
    @Test func reopeningAnAyahInTheSurahHeldSelectsAndScrollsToIt() async throws {
        let (model, _, _) = Self.makeModel()
        await model.load()
        let verse = VerseReference(surah: 2, verse: 255)

        model.open(.surah(2))
        model.separatedTopAyahDidChange(VerseReference(surah: 2, verse: 40))

        model.open(.ayah(verse))

        #expect(model.separatedSurah == 2)
        #expect(model.separatedLocation == verse)
        #expect(model.mushaf.selectedAyah == verse)
        #expect(model.separatedScrollRequest?.ayah == verse)
    }

    // MARK: Opening a target

    @Test func aTargetInAnotherSurahChangesTheSurahAndSetsNoRequest() async throws {
        let (model, _, _) = Self.makeModel()
        await model.load()

        model.open(.ayah(VerseReference(surah: 2, verse: 255)))

        #expect(model.separatedSurah == 2)
        #expect(model.separatedScrollRequest == nil)
    }

    @Test func aTargetInTheSameSurahKeepsItAndSetsARequest() async throws {
        let (model, _, _) = Self.makeModel()
        await model.load()
        model.open(.ayah(VerseReference(surah: 2, verse: 255)))

        model.open(.ayah(VerseReference(surah: 2, verse: 1)))

        #expect(model.separatedSurah == 2)
        #expect(model.separatedScrollRequest?.ayah == VerseReference(surah: 2, verse: 1))
    }

    @Test func theSameAyahOpenedTwiceGivesTwoDifferentRequests() async throws {
        let (model, _, _) = Self.makeModel()
        await model.load()
        let verse = VerseReference(surah: 2, verse: 255)
        model.open(.ayah(verse))

        model.open(.ayah(verse))
        let first = try #require(model.separatedScrollRequest)
        model.open(.ayah(verse))
        let second = try #require(model.separatedScrollRequest)

        #expect(first.ayah == verse && second.ayah == verse)
        #expect(first != second, "a request nobody consumed must not swallow the next one")
    }

    @Test func anUnresolvableTargetChangesNeitherPageSurahNorSelection() async throws {
        let (model, _, _) = Self.makeModel()
        await model.load()
        let verse = VerseReference(surah: 2, verse: 255)
        model.open(.ayah(verse))
        model.select(verse)
        let pageBefore = model.mushaf.page
        let surahBefore = model.separatedSurah
        let selectionBefore = model.mushaf.selectedAyah

        // Surah 2 has 286 verses, and there is no surah 115.
        model.open(.ayah(VerseReference(surah: 2, verse: 287)))
        model.open(.surah(115))

        #expect(model.mushaf.page == pageBefore)
        #expect(model.separatedSurah == surahBefore)
        #expect(model.mushaf.selectedAyah == selectionBefore)
    }

    // MARK: Selection

    /// Ported from Mushaf's `selectingAnAyahNoLongerPresentsFromTheModel`: selecting an ayah sets the
    /// selection and the location, and presents nothing (there is no presentation state on the
    /// model; the scroll request and the surah are the nearest things it could move).
    @Test func selectingAnAyahNoLongerPresentsFromTheModel() async throws {
        let repository = CountingQuranRepository()
        await repository.setFailing(true)
        let (model, _, _) = Self.makeModel(repository: repository)
        await model.load()
        let ayah = VerseReference(surah: 18, verse: 10)

        model.select(ayah)

        #expect(model.mushaf.selectedAyah == ayah)
        #expect(model.location == ayah)
        #expect(model.separatedScrollRequest == nil)
        #expect(model.separatedSurah == 1)
    }

    @Test func selectingTogglesTheSelectionAndPresentsNothing() async throws {
        let (model, _, _) = Self.makeModel()
        await model.load()
        let ayah = VerseReference(surah: 2, verse: 255)

        model.select(ayah)
        #expect(model.mushaf.selectedAyah == ayah)

        model.select(ayah)
        #expect(model.mushaf.selectedAyah == nil)
        #expect(model.separatedScrollRequest == nil)
        #expect(model.separatedSurah == 1)
    }

    // MARK: Settings writes

    @Test func loadingAndOpeningWriteNoSettingsKey() async throws {
        let (model, _, store) = Self.makeModel()

        await model.load()
        model.open(.ayah(VerseReference(surah: 2, verse: 255)))
        model.open(.ayah(VerseReference(surah: 2, verse: 1)))
        model.select(VerseReference(surah: 2, verse: 1))

        #expect(Self.storedKeys(in: store).isEmpty)
    }

    @Test func loadingAFailedRepositoryWritesNoSettingsKey() async throws {
        let repository = CountingQuranRepository()
        await repository.setFailing(true)
        let (model, _, store) = Self.makeModel(repository: repository)

        await model.load()

        #expect(Self.storedKeys(in: store).isEmpty)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func theModeToggleWritesTheDisplayModeKeyAndNothingElse() async throws {
        let (model, _, store) = Self.makeModel(repository: QuranTestData.repository(QuranTestData.fullDatabase))
        await model.load()
        #expect(Self.storedKeys(in: store).isEmpty)

        model.toggleDisplayMode()
        #expect(Self.storedKeys(in: store) == [.quranDisplayMode])
        #expect(store.string(for: .quranDisplayMode) == QuranDisplayMode.separated.rawValue)

        model.toggleDisplayMode()
        #expect(Self.storedKeys(in: store) == [.quranDisplayMode])
        #expect(store.string(for: .quranDisplayMode) == QuranDisplayMode.mushaf.rawValue)
    }

    // MARK: Immersive

    /// The question over its four inputs. Pages are needed for `true`, so this is the full build.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func theImmersiveQuestionOverItsInputs() async throws {
        for allowsImmersive in [true, false] {
            for chromeHidden in [true, false] {
                for voiceOver in [true, false] {
                    let (model, _, _) = Self.makeModel(
                        repository: QuranTestData.repository(QuranTestData.fullDatabase),
                        allowsImmersive: allowsImmersive
                    )
                    await model.load()
                    #expect(model.showsMushafPages)
                    model.mushaf.isChromeHidden = chromeHidden

                    let expected = allowsImmersive && chromeHidden && !voiceOver
                    #expect(
                        model.isImmersive(voiceOverRunning: voiceOver) == expected,
                        "allowsImmersive \(allowsImmersive), chromeHidden \(chromeHidden), voiceOver \(voiceOver)"
                    )
                }
            }
        }
    }

    @Test func theImmersiveQuestionIsFalseWhilePagesAreNotShowing() async throws {
        let (model, _, _) = Self.makeModel(allowsImmersive: true)
        await model.load()
        model.mushaf.isChromeHidden = true

        #expect(!model.showsMushafPages)
        #expect(!model.isImmersive(voiceOverRunning: false))
    }

    @Test func exitingImmersiveClearsTheRequest() async throws {
        let (model, _, _) = Self.makeModel()
        await model.load()
        model.mushaf.isChromeHidden = true

        model.exitImmersive()

        #expect(!model.mushaf.isChromeHidden)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func switchingToSeparatedClearsTheImmersiveRequest() async throws {
        let (model, _, _) = Self.makeModel(repository: QuranTestData.repository(QuranTestData.fullDatabase))
        await model.load()
        model.mushaf.isChromeHidden = true

        model.setDisplayMode(.separated)

        #expect(!model.mushaf.isChromeHidden)
        #expect(!model.isImmersive(voiceOverRunning: false))
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func aModelBuiltWithoutImmersiveIsNeverImmersive() async throws {
        let (model, _, _) = Self.makeModel(
            repository: QuranTestData.repository(QuranTestData.fullDatabase),
            allowsImmersive: false
        )
        await model.load()
        model.mushaf.isChromeHidden = true

        #expect(model.showsMushafPages)
        #expect(!model.isImmersive(voiceOverRunning: false))
    }
}
