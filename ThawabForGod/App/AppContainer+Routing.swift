//
//  AppContainer+Routing.swift
//  ThawabForGod
//

import Foundation

extension AppContainer {

    /// Opens a route, wherever in the app it happens to live.
    ///
    /// The one place that knows a tap on Home's "continue reading" card has to select a different
    /// *tab* and then drive that tab's coordinator. That knowledge belongs at the composition
    /// root and nowhere else: it is the only layer entitled to know that four otherwise unrelated
    /// features share a window, which is the same argument `MainTabView` is assembled here for.
    ///
    /// Note the ordering. The tab is selected first, so the coordinator's change lands on a stack
    /// that is already on screen — the other way round, the push happens behind a tab nobody is
    /// looking at and arrives as a jump when they switch to it.
    func open(_ route: AppRoute) {
        switch route {
        case .qibla:
            router.selectedTab = .home
            homeCoordinator.show(.qibla)

        case .tasbih:
            router.selectedTab = .home
            homeCoordinator.show(.tasbih)

        case .names:
            router.selectedTab = .home
            homeCoordinator.show(.names)

        case .adhkar(let categoryID):
            router.selectedTab = .adhkar
            adhkarCoordinator.open(categoryID: categoryID)

        case .quran:
            router.selectedTab = .quran
            quranCoordinator.closeReading()

        case .quranVerse(let reference):
            router.selectedTab = .quran
            quranCoordinator.open(reference)
        }
    }
}
