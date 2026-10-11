//
//  AppSectionView.swift
//  ThawabForGod
//

import SwiftUI

/// One section of the app, with its navigation stack, built from the composition root.
///
/// This is what a tab holds and what the sidebar's detail column shows — the same view either
/// way, which is the point. `MainTabView` and `MainSplitView` are two arrangements of one set of
/// sections, so the sections themselves live here rather than being written out twice; a screen
/// wired into only one of them would be a screen the iPhone can reach and the iPad cannot.
///
/// Assembled at the composition root because it is the only layer entitled to know that five
/// otherwise unrelated features share a window. The sections read their view models straight off
/// the container — each of those accessors is cached, so a redraw of this view builds nothing.
///
/// Every section carries its **own** `NavigationStack`. That is what makes a tab bar work —
/// switching sections preserves where each one was left — and it is equally what the detail
/// column needs, since a stack nested in another stack breaks the back gesture and the toolbar
/// both. The stacks' paths live on the coordinators rather than in `@State` here, which is also
/// why the iPad can swap between the tab bar and the sidebar mid-session without losing anyone's
/// place: the state was never in the view tree to lose.
struct AppSectionView: View {
    let container: AppContainer
    let tab: AppTab

    var body: some View {
        switch tab {
        case .home: home
        case .quran: quran
        case .hadith: hadith
        case .adhkar: adhkar
        case .settings: settings
        }
    }

    /// Prayer times, plus the three screens that are still visits rather than destinations:
    /// the Qibla, the tasbih and the 99 names, all pushed onto this section's own stack.
    private var home: some View {
        HomeCoordinatorView(
            coordinator: container.homeCoordinator,
            viewModel: container.homeViewModel(),
            qiblaCoordinator: container.qiblaCoordinator,
            qiblaViewModel: container.qiblaViewModel(),
            tasbihCoordinator: container.tasbihCoordinator,
            tasbihViewModel: container.tasbihViewModel(),
            namesCoordinator: container.namesCoordinator,
            namesViewModel: container.namesViewModel(),
            // The one layer entitled to know that a tap on Home can land in another section.
            open: container.open,
            customizationViewModel: container.homeCustomizationViewModel(),
            prayerTimesViewModel: container.prayerTimesSheetViewModel()
        )
    }

    /// The Quran: the Library at the root, with the reader or a surah's introduction pushed over it.
    ///
    /// Driven from a typed path on `QuranCoordinator`, so a route from outside (a verse link, a
    /// quick action) can open the reader without reaching into the view tree. The reader view model
    /// is one for the section, shared by the root and the reader, which is what makes the corpus
    /// load once and keeps the reading place when the view tree is rebuilt. The section's chrome
    /// modifier sits on the stack because that is where the status-bar setting takes effect.
    private var quran: some View {
        @Bindable var coordinator = container.quranCoordinator
        let viewModel = container.quranReaderViewModel
        let library = container.quranLibraryViewModel

        return NavigationStack(path: $coordinator.path) {
            QuranLibraryView(viewModel: library, coordinator: container.quranCoordinator)
                .navigationDestination(for: QuranRoute.self) { route in
                    switch route {
                    case .reader:
                        QuranReaderView(
                            viewModel: viewModel,
                            coordinator: container.quranCoordinator,
                            panel: container.quranAyahPanelViewModel,
                            faces: container.quranFaces,
                            services: container.mushafRenderServices
                        )
                        #if DEBUG
                        .quranLaunchHooks(viewModel: viewModel, container: container)
                        #endif
                    case .surahInfo(let surah):
                        SurahInfoView(viewModel: container.quranSurahInfoViewModel, surah: surah)
                    }
                }
        }
        // The Library and surah info draw a QUL face too; until now only the reading surface set this.
        .environment(\.quranFaces, container.quranFaces)
        // On the stack, not only on the root: when the reader is the first screen of the session the
        // index is built behind it, so the root's first frame already has its rows.
        .task { await library.load(language: container.localizationManager.language) }
        .quranSectionChrome(coordinator: container.quranCoordinator, viewModel: viewModel)
    }

    /// The two Sahihs, each pushing into its divisions and then into the narrations.
    ///
    /// Two pushes deep, which is what a collection of collections costs — so this section drives
    /// its stack from a path, like the Quran and Settings, rather than from a chain of
    /// `navigationDestination(item:)`. That is also what lets a search result land two levels down
    /// in one move; see `HadithCoordinator`.
    private var hadith: some View {
        @Bindable var coordinator = container.hadithCoordinator

        return NavigationStack(path: $coordinator.path) {
            HadithCollectionListView(
                viewModel: container.hadithViewModel(),
                coordinator: container.hadithCoordinator
            )
            // Declared once, at the root, so every level of this section is reachable from every
            // other — which is the whole point of a path over nested destinations.
            .navigationDestination(for: HadithRoute.self) { route in
                switch route {
                case .collection(let collection):
                    HadithBookListView(
                        viewModel: container.hadithViewModel(),
                        coordinator: container.hadithCoordinator,
                        collection: collection
                    )

                case .book(let reference):
                    HadithReadingView(
                        viewModel: container.hadithViewModel(),
                        coordinator: container.hadithCoordinator,
                        reference: reference
                    )

                case .memorize:
                    HadithMemorizeView(viewModel: container.hadithMemorizeViewModel())
                }
            }
        }
    }

    /// A section rather than a push, because reading the morning or evening adhkar is a sitting —
    /// the reader comes back to it, and a section remembers where they were.
    private var adhkar: some View {
        NavigationStack {
            AdhkarCategoryListView(
                viewModel: container.adhkarViewModel(),
                coordinator: container.adhkarCoordinator
            )
        }
    }

    /// iOS and iPadOS only — see `AppTab.visible`. On the Mac this case is unreachable: the
    /// section is not in the list either presentation builds from, and nothing sets the router to
    /// it. Rendering the screen here anyway would be worse than empty, because the `Settings`
    /// scene already binds `SettingsCoordinator.path` to a stack of its own and two stacks on one
    /// path fight each other.
    @ViewBuilder
    private var settings: some View {
        #if os(iOS)
        @Bindable var coordinator = container.settingsCoordinator

        NavigationStack(path: $coordinator.path) {
            SettingsView(
                container: container.settings,
                coordinator: container.settingsCoordinator
            )
        }
        #endif
    }
}
