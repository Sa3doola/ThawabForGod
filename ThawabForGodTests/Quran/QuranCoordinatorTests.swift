//
//  QuranCoordinatorTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The Quran tab's path, and the place a target puts the reader at (M5.1, design section 4.3).
///
/// A target is applied to the reader's view model before the reader is pushed, so the reader's first
/// frame is already at the target. That is what the place cases assert: on the view model, and at the
/// moment `open` returns, with no `await` in between.
///
/// Ported from Mushaf's `AppRouterTests`, which tested the sheet and panel state this coordinator does
/// not have yet. Its `presentsOneSheetAtATime` and the panel cases are deferred to the tasks that
/// declare `QuranSheet`; its `selectingAnAyahNoLongerPresentsFromTheModel` and `emptyEnvironmentHasNoData`
/// are view-model cases and live in `QuranReaderViewModelTests`.
///
/// The view model reads the public (Tanzil) database explicitly, so every case here runs where the full
/// data is also bundled. Ayahs used are in both builds, and the place is the ayah and the surah, which
/// do not depend on the printed layout.
@MainActor
struct QuranCoordinatorTests {

    private func makeCoordinator() -> (coordinator: QuranCoordinator, reader: QuranReaderViewModel) {
        let reader = QuranReaderViewModel(
            repository: QuranTestData.repository(QuranTestData.publicDatabase),
            settings: QuranReaderSettings(settingsStore: InMemorySettingsStore()),
            allowsImmersive: true
        )
        return (QuranCoordinator(reader: reader), reader)
    }

    // MARK: The path

    @Test func aFreshCoordinatorHasNoPathAndTheReaderIsNotOnTop() {
        let (coordinator, _) = makeCoordinator()
        #expect(coordinator.path.isEmpty)
        #expect(!coordinator.isReaderOnTop)
    }

    @Test func openPushesTheReader() {
        let (coordinator, _) = makeCoordinator()

        coordinator.open(.surah(2))

        #expect(coordinator.path == [.reader])
        #expect(coordinator.isReaderOnTop)
    }

    /// The path never holds two readers. With the reader already on screen a second open retargets it
    /// in place and deepens nothing.
    @Test func openTwiceLeavesOneReader() {
        let (coordinator, _) = makeCoordinator()

        coordinator.open(.page(50))
        coordinator.open(.surah(2))

        #expect(coordinator.path == [.reader])
    }

    @Test func openReaderPushesTheReaderWithoutATarget() {
        let (coordinator, _) = makeCoordinator()

        coordinator.openReader()

        #expect(coordinator.path == [.reader])
        #expect(coordinator.isReaderOnTop)
    }

    @Test func popToRootEmptiesThePath() {
        let (coordinator, _) = makeCoordinator()
        coordinator.open(.page(50))

        coordinator.popToRoot()

        #expect(coordinator.path.isEmpty)
        #expect(!coordinator.isReaderOnTop)
    }

    @Test func isReaderOnTopFollowsThePath() {
        let (coordinator, _) = makeCoordinator()
        coordinator.open(.page(1))
        #expect(coordinator.isReaderOnTop)

        coordinator.path = []
        #expect(!coordinator.isReaderOnTop)
    }

    // MARK: The place

    /// The reader is at the ayah the moment `open` returns: the place is asserted with no `await` after
    /// the `open`, so nothing could have applied it later.
    @Test func theReaderIsAtTheTargetTheMomentOpenReturns() async throws {
        let (coordinator, reader) = makeCoordinator()
        await reader.load()

        coordinator.open(.ayah(VerseReference(surah: 2, verse: 255)))

        #expect(coordinator.path == [.reader])
        #expect(reader.separatedSurah == 2)
        #expect(reader.location == VerseReference(surah: 2, verse: 255))
        #expect(reader.mushaf.selectedAyah == VerseReference(surah: 2, verse: 255))
    }

    /// A target opened before the corpus is there is parked on the reader, and applied when it arrives.
    @Test func aTargetOpenedBeforeTheLoadIsAppliedAfterIt() async throws {
        let (coordinator, reader) = makeCoordinator()

        coordinator.open(.ayah(VerseReference(surah: 2, verse: 255)))
        #expect(coordinator.path == [.reader])
        #expect(reader.separatedSurah == 1, "nothing moves before the corpus is there")

        await reader.load()

        #expect(reader.separatedSurah == 2)
        #expect(reader.location == VerseReference(surah: 2, verse: 255))
    }

    /// A second open to another surah moves the place and still leaves one reader on the path.
    @Test func aSecondOpenMovesThePlaceAndKeepsOneReader() async throws {
        let (coordinator, reader) = makeCoordinator()
        await reader.load()
        coordinator.open(.ayah(VerseReference(surah: 2, verse: 255)))

        coordinator.open(.ayah(VerseReference(surah: 18, verse: 10)))

        #expect(coordinator.path == [.reader])
        #expect(reader.separatedSurah == 18)
        #expect(reader.location == VerseReference(surah: 18, verse: 10))
    }

    /// Opening the reader where it was left does not move the place.
    @Test func openReaderDoesNotMoveThePlace() async throws {
        let (coordinator, reader) = makeCoordinator()
        await reader.load()
        coordinator.open(.ayah(VerseReference(surah: 2, verse: 255)))
        coordinator.path = []

        coordinator.openReader()

        #expect(coordinator.path == [.reader])
        #expect(reader.separatedSurah == 2)
        #expect(reader.location == VerseReference(surah: 2, verse: 255))
    }

    /// Popping to the root does not move the place either: the reader keeps where it was, so the next
    /// open from the root starts from there.
    @Test func popToRootDoesNotMoveThePlace() async throws {
        let (coordinator, reader) = makeCoordinator()
        await reader.load()
        coordinator.open(.ayah(VerseReference(surah: 2, verse: 255)))

        coordinator.popToRoot()

        #expect(coordinator.path.isEmpty)
        #expect(reader.separatedSurah == 2)
        #expect(reader.location == VerseReference(surah: 2, verse: 255))
    }

    // MARK: Surah info (M5.2)

    /// Pushed from a Library row with nothing else on the path: surah info alone above the root.
    @Test func showSurahInfoFromTheRootPushesIt() {
        let (coordinator, _) = makeCoordinator()

        coordinator.showSurahInfo(18)

        #expect(coordinator.path == [.surahInfo(18)])
        #expect(!coordinator.isReaderOnTop)
    }

    /// Asking for the screen already in front pushes nothing.
    @Test func showSurahInfoTwiceGivesItOnce() {
        let (coordinator, _) = makeCoordinator()

        coordinator.showSurahInfo(18)
        coordinator.showSurahInfo(18)

        #expect(coordinator.path == [.surahInfo(18)])
    }

    /// From the reader, surah info sits above it, and the reader is still the first screen on the path.
    @Test func showSurahInfoWithTheReaderOpenSitsAboveIt() {
        let (coordinator, _) = makeCoordinator()
        coordinator.open(.surah(2))

        coordinator.showSurahInfo(18)

        #expect(coordinator.path == [.reader, .surahInfo(18)])
        #expect(!coordinator.isReaderOnTop)
    }

    /// Opening the reader from surah info replaces the stack with the reader: one reader, nothing above it.
    @Test func openFromSurahInfoReplacesTheStackWithTheReader() {
        let (coordinator, _) = makeCoordinator()
        coordinator.showSurahInfo(18)

        coordinator.open(.surah(2))

        #expect(coordinator.path == [.reader])
        #expect(coordinator.isReaderOnTop)
    }

    @Test func popToRootEmptiesSurahInfoToo() {
        let (coordinator, _) = makeCoordinator()
        coordinator.open(.surah(2))
        coordinator.showSurahInfo(18)

        coordinator.popToRoot()

        #expect(coordinator.path.isEmpty)
    }

    // MARK: Continue reading (M5.2)

    @Test func aFreshCoordinatorCannotContinueReading() {
        let (coordinator, _) = makeCoordinator()
        #expect(!coordinator.canContinueReading, "there is no place yet")
    }

    /// The reader is on the path, so there is nothing to continue to; the same holds under surah info.
    @Test func continueReadingIsOfferedOnlyWhileTheReaderIsOffTheStack() {
        let (coordinator, _) = makeCoordinator()
        coordinator.open(.surah(2))
        #expect(!coordinator.canContinueReading)

        coordinator.showSurahInfo(18)
        #expect(!coordinator.canContinueReading, "the reader is still on the path, under surah info")
    }

    @Test func continueReadingIsOfferedAfterThePopToRoot() {
        let (coordinator, _) = makeCoordinator()
        coordinator.open(.surah(2))

        coordinator.popToRoot()

        #expect(coordinator.canContinueReading)
    }

    /// Surah info pushed alone, after the reader was shown and popped, keeps the place: the reader is not
    /// on the path, and it was shown in this process.
    @Test func continueReadingSurvivesSurahInfoPushedAlone() {
        let (coordinator, _) = makeCoordinator()
        coordinator.open(.surah(2))
        coordinator.popToRoot()

        coordinator.showSurahInfo(18)

        #expect(coordinator.path == [.surahInfo(18)])
        #expect(coordinator.canContinueReading)
    }
}

/// The external routes that land in the Quran tab, driven through a real container.
///
/// Built the way `DeepLinkRoutingTests` builds one: in-memory persistence, mock location and
/// notifications, background refresh off. The thing under test is the wiring from `AppRoute` and
/// `DeepLink` to the Quran coordinator, and to the reader's place, so the tab selection, the
/// coordinator and the view model are all real.
///
/// The container opens whichever database is bundled (`quranDatabase`, the full one where it exists).
/// Nothing here needs the printed layout: the ayah and its surah are the same in both builds, so no case
/// is pinned to the public database.
@MainActor
struct QuranRoutingTests {

    private func makeContainer() throws -> AppContainer {
        AppContainer(
            settingsStore: InMemorySettingsStore(bools: [.onboardingCompleted: true]),
            persistence: try PersistenceController(inMemory: true),
            locationService: MockLocationService(),
            notificationService: MockNotificationService(),
            registersBackgroundRefresh: false
        )
    }

    /// The verse route selects the Quran tab and pushes the reader.
    @Test func theQuranVerseRouteSelectsTheTabAndPushesTheReader() throws {
        let container = try makeContainer()
        container.router.selectedTab = .home

        container.open(AppRoute.quranVerse(VerseReference(surah: 2, verse: 255)))

        #expect(container.router.selectedTab == .quran)
        #expect(container.quranCoordinator.path == [.reader])
    }

    /// Once the corpus is loaded the reader is at the verse the route named. `separatedLocation` and the
    /// selection are asserted rather than `location`: in a full build Mushaf is the default, and
    /// `location` then reads the page's first ayah, which is a different verse by design.
    @Test func theQuranVerseRouteLeavesTheReaderAtTheAyah() async throws {
        let container = try makeContainer()
        let reference = VerseReference(surah: 2, verse: 255)

        container.open(AppRoute.quranVerse(reference))
        await container.quranReaderViewModel.load()

        #expect(container.quranReaderViewModel.separatedSurah == 2)
        #expect(container.quranReaderViewModel.separatedLocation == reference)
        #expect(container.quranReaderViewModel.mushaf.selectedAyah == reference)
    }

    /// `.quran` means "the tab, at its list": the reader is popped.
    @Test func theQuranRouteSelectsTheTabAndPopsAnOpenReader() throws {
        let container = try makeContainer()
        container.quranCoordinator.open(.surah(2))
        container.router.selectedTab = .home

        container.open(AppRoute.quran)

        #expect(container.router.selectedTab == .quran)
        #expect(container.quranCoordinator.path.isEmpty)
    }

    /// A verse link tapped while the reader is already on screen retargets it in place: one reader on
    /// the path, and the place moves to the verse once the corpus is there.
    @Test func theQuranVerseRouteRetargetsAReaderAlreadyOnScreen() async throws {
        let container = try makeContainer()
        let reference = VerseReference(surah: 2, verse: 255)
        await container.quranReaderViewModel.load()
        container.quranCoordinator.open(.surah(18))

        container.open(AppRoute.quranVerse(reference))

        #expect(container.quranCoordinator.path == [.reader])
        #expect(container.quranReaderViewModel.separatedSurah == 2)
        #expect(container.quranReaderViewModel.separatedLocation == reference)
    }

    /// The deep link is a promise that resolves to the same route, so it must land exactly where the
    /// route does: the tab and an empty path.
    @Test func theQuranDeepLinkLandsWhereTheRouteDoes() throws {
        let container = try makeContainer()
        container.quranCoordinator.open(.surah(2))
        container.router.selectedTab = .home

        container.open(DeepLink.quran)

        #expect(container.router.selectedTab == .quran)
        #expect(container.quranCoordinator.path.isEmpty)
    }
}
