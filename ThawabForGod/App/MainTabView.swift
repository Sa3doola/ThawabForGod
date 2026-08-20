//
//  MainTabView.swift
//  ThawabForGod
//

import SwiftUI

/// The main interface: four tabs, each owning a navigation stack of its own.
///
/// This replaces the single stack Home used to own, and it is the answer `HomeCoordinatorView`'s
/// documentation kept promising — the toolbar had run out of room, and the Quran is too large a
/// thing to reach through a menu. Each tab gets its own `NavigationStack`, which is what makes a
/// tab bar work: switching tabs preserves where each one was left, and nothing is nested inside
/// anything else.
///
/// Assembled here, at the composition root, because it is the only layer entitled to know that
/// four otherwise unrelated features share a window. The tabs read their view models straight off
/// the container — each of those accessors is cached, so a redraw of this view builds nothing.
///
/// **`.tabItem` rather than the `Tab` value builder**, which is iOS 18. The deployment target is
/// iOS 17, so this is the API that exists.
struct MainTabView: View {
    let container: AppContainer

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        // The selection lives on the router, so a later deep link can move the user between tabs
        // without this view being involved. `@Bindable` is what turns that into a binding.
        @Bindable var router = container.router

        TabView(selection: $router.selectedTab) {
            homeTab
                .tabItem { Label(l10n.string(.homeTabLabel), systemImage: AppTab.home.symbol) }
                .tag(AppTab.home)

            quranTab
                .tabItem { Label(l10n.string(.quranTitle), systemImage: AppTab.quran.symbol) }
                .tag(AppTab.quran)

            adhkarTab
                .tabItem { Label(l10n.string(.adhkarTitle), systemImage: AppTab.adhkar.symbol) }
                .tag(AppTab.adhkar)

            #if os(iOS)
            // iOS and iPadOS only — see `AppTab.settings`. The Mac reaches this same screen
            // through its own `Settings` scene and ⌘,.
            settingsTab
                .tabItem { Label(l10n.string(.settingsTitle), systemImage: AppTab.settings.symbol) }
                .tag(AppTab.settings)
            #endif
        }
    }

    /// Prayer times, plus the three screens that are still visits rather than destinations:
    /// the Qibla, the tasbih and the 99 names, all pushed onto this tab's own stack.
    private var homeTab: some View {
        HomeCoordinatorView(
            coordinator: container.homeCoordinator,
            viewModel: container.homeViewModel(),
            qiblaCoordinator: container.qiblaCoordinator,
            qiblaViewModel: container.qiblaViewModel(),
            tasbihCoordinator: container.tasbihCoordinator,
            tasbihViewModel: container.tasbihViewModel(),
            namesCoordinator: container.namesCoordinator,
            namesViewModel: container.namesViewModel(),
            // The one layer entitled to know that a tap on Home can land in another tab.
            open: container.open,
            customizationViewModel: container.homeCustomizationViewModel(),
            prayerTimesViewModel: container.prayerTimesSheetViewModel()
        )
    }

    /// The chapters and the parts, each pushing into the reading screen.
    ///
    /// A tab rather than a push for the same reason the adhkar are: reading is a sitting the
    /// reader returns to, and a tab is what remembers where they were.
    private var quranTab: some View {
        NavigationStack {
            QuranListView(
                viewModel: container.quranViewModel(),
                coordinator: container.quranCoordinator,
                settings: container.readerSettings
            )
        }
    }

    /// A tab rather than a push, because reading the morning or evening adhkar is a sitting —
    /// the reader comes back to it, and a tab remembers where they were.
    private var adhkarTab: some View {
        NavigationStack {
            AdhkarCategoryListView(
                viewModel: container.adhkarViewModel(),
                coordinator: container.adhkarCoordinator
            )
        }
    }

    #if os(iOS)
    private var settingsTab: some View {
        NavigationStack {
            SettingsView(
                viewModel: container.settingsViewModel(),
                coordinator: container.settingsCoordinator,
                customizationViewModel: container.homeCustomizationViewModel()
            )
        }
    }
    #endif
}
