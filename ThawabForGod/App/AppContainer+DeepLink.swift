//
//  AppContainer+DeepLink.swift
//  ThawabForGod
//

import Foundation

extension AppContainer {

    /// Opens a link that arrived from outside the app — a widget tap, a Home Screen quick
    /// action, a Dock menu item, or a `noor://` URL.
    ///
    /// The translation layer between the app's stable external vocabulary and its internal
    /// routing. `DeepLink` says what the outside world asked for; `AppRoute` and the coordinators
    /// say how this build answers it, and the two are free to move independently as long as this
    /// one function keeps up.
    ///
    /// Most cases delegate straight to `open(_ route: AppRoute)`, which already knows the rule
    /// about selecting the tab before driving its coordinator. The four that do not are the four
    /// `AppRoute` has no case for, because nothing *inside* the app ever needed to ask for them.
    func open(_ link: DeepLink) {
        switch link {
        case .home:
            // Deliberately no `popToRoot()`. A tab is a place the reader returns to and expects
            // to find where they left it — throwing away a pushed screen because a widget said
            // "home" would be this link deciding something the reader already decided.
            router.selectedTab = .home

        case .prayerTimes:
            // This one *does* pop, and for the opposite reason: the sheet is a look at the day,
            // and putting it up over whatever happened to be pushed would present it over the
            // Qibla compass.
            router.selectedTab = .home
            homeCoordinator.popToRoot()
            homeCoordinator.isShowingPrayerTimes = true

        case .qibla:
            open(AppRoute.qibla)

        case .tasbih:
            open(AppRoute.tasbih)

        case .names:
            open(AppRoute.names)

        case .adhkar:
            router.selectedTab = .adhkar
            adhkarCoordinator.closeCategory()

        case .adhkarCategory(let period):
            open(AppRoute.adhkar(AdhkarCategory(period)))

        case .quran:
            open(AppRoute.quran)

        case .hadith:
            router.selectedTab = .hadith
            hadithCoordinator.popToRoot()

        case .settings:
            #if os(iOS)
            router.selectedTab = .settings
            settingsCoordinator.popToRoot()
            #endif
            // macOS has no Settings tab, for the same reason it has never had a toolbar gear:
            // that build reaches the screen through the `Settings` scene and ⌘,. A link cannot
            // open a scene it does not own, so this is a no-op rather than a wrong answer.
        }
    }
}

private nonisolated extension AdhkarCategory {
    /// The link's vocabulary, resolved into the feature's.
    ///
    /// Total by construction — every `DeepLink.Period` names a category that exists — which is
    /// what lets `open(_:)` above stay free of optionals. The day the corpus grows a category,
    /// this is where the two lists are reconciled and the compiler names the file.
    init(_ period: DeepLink.Period) {
        switch period {
        case .morning: self = .morning
        case .evening: self = .evening
        }
    }
}
