//
//  DeepLinkRoutingTests.swift
//  ThawabForGodTests
//

import Foundation
import SwiftUI // NavigationPath.count; MEMBER_IMPORT_VISIBILITY means it is not re-exported
import Testing
@testable import ThawabForGod

/// Where each link actually lands, driven through a real container.
///
/// Built the way `AppRoutingTests` builds one — in-memory persistence, mock location and
/// notifications, background refresh off — because the thing under test is the *wiring*: a link
/// has to select a tab and drive that tab's coordinator, and a test that stubbed either half
/// would pass while the app opened the wrong screen.
@MainActor
struct DeepLinkRoutingTests {

    private func makeContainer() throws -> AppContainer {
        AppContainer(
            settingsStore: InMemorySettingsStore(bools: [.onboardingCompleted: true]),
            persistence: try PersistenceController(inMemory: true),
            locationService: MockLocationService(),
            notificationService: MockNotificationService(),
            registersBackgroundRefresh: false
        )
    }

    // MARK: Tab selection

    @Test func eachLinkSelectsItsSection() throws {
        let container = try makeContainer()

        let expectations: [(DeepLink, AppTab)] = [
            (.home, .home),
            (.prayerTimes, .home),
            (.qibla, .home),
            (.tasbih, .home),
            (.names, .home),
            (.adhkar, .adhkar),
            (.adhkarCategory(.evening), .adhkar),
            (.quran, .quran),
            (.hadith, .hadith)
        ]

        for (link, tab) in expectations {
            container.router.selectedTab = .quran // somewhere else first, so a no-op would show
            container.open(link)
            #expect(container.router.selectedTab == tab, "\(link) should select \(tab)")
        }
    }

    // MARK: What each link does once it is there

    @Test func theThreeLibraryScreensArePushedOntoHome() throws {
        let container = try makeContainer()

        container.open(DeepLink.qibla)
        #expect(container.homeCoordinator.path.count == 1)

        container.open(DeepLink.tasbih)
        #expect(container.homeCoordinator.path.count == 2)
    }

    /// Home is a place the reader returns to, so arriving there must not throw away what they
    /// had pushed. This is the difference between `.home` and `.prayerTimes` below.
    @Test func homeLeavesAPushedScreenWhereItIs() throws {
        let container = try makeContainer()
        container.open(DeepLink.qibla)

        container.open(DeepLink.home)

        #expect(container.router.selectedTab == .home)
        #expect(container.homeCoordinator.path.count == 1)
    }

    /// The day sheet is a look at the day, not a destination — presenting it over the Qibla
    /// compass would be presenting it over the wrong screen, so this one does pop.
    @Test func prayerTimesPopsHomeBeforeRaisingTheSheet() throws {
        let container = try makeContainer()
        container.open(DeepLink.qibla)

        container.open(DeepLink.prayerTimes)

        #expect(container.homeCoordinator.path.isEmpty)
        #expect(container.homeCoordinator.isShowingPrayerTimes)
    }

    /// **Both periods open the same chapter**, and that is the corpus telling the truth rather
    /// than the link being sloppy. Hisn al-Muslim has one chapter for both times of day; the link
    /// keeps two cases because it is a promise iOS caches across builds, and this is the one place
    /// the two vocabularies are reconciled.
    @Test func eitherAdhkarPeriodOpensTheMorningAndEveningChapter() throws {
        let container = try makeContainer()

        for period in DeepLink.Period.allCases {
            container.adhkarCoordinator.closeCategory()
            container.open(DeepLink.adhkarCategory(period))

            #expect(container.adhkarCoordinator.openCategoryID == AdhkarCategory.morningAndEveningID)
        }
    }

    /// The bare link is the list, and it has to *close* whatever category was open — otherwise
    /// tapping "Adhkar" from the Home Screen at seven in the evening reopens the morning ones.
    @Test func theBareAdhkarLinkReturnsToTheList() throws {
        let container = try makeContainer()
        container.open(DeepLink.adhkarCategory(.morning))

        container.open(DeepLink.adhkar)

        #expect(container.adhkarCoordinator.openCategoryID == nil)
    }

    @Test func hadithReturnsToItsCollections() throws {
        let container = try makeContainer()
        container.hadithCoordinator.path = [.memorize]

        container.open(DeepLink.hadith)

        #expect(container.hadithCoordinator.path.isEmpty)
    }

    /// macOS has no Settings tab — that build reaches the screen through ⌘, and the `Settings`
    /// scene. The link is a no-op there rather than selecting a section that does not exist.
    @Test func settingsOpensOnlyWhereThereIsATabForIt() throws {
        let container = try makeContainer()
        container.router.selectedTab = .quran

        container.open(DeepLink.settings)

        #if os(iOS)
        #expect(container.router.selectedTab == .settings)
        #else
        #expect(container.router.selectedTab == .quran)
        #endif
    }

    // MARK: The inbox

    /// A link is consumed, not read. Opening the same one twice because something else caused
    /// the observer to re-evaluate is the failure this is shaped to prevent.
    @Test func theInboxHandsALinkOverExactlyOnce() throws {
        let container = try makeContainer()

        container.deepLinks.receive(.qibla)

        #expect(container.deepLinks.consume() == .qibla)
        #expect(container.deepLinks.consume() == nil)
        #expect(container.deepLinks.pending == nil)
    }

    /// The composition root publishes its own inbox, which is what the scene delegate posts to.
    @Test func theContainerPublishesItsInbox() throws {
        let container = try makeContainer()

        #expect(DeepLinkInbox.current === container.deepLinks)
    }
}
