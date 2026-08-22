//
//  HomeCoordinatorView.swift
//  ThawabForGod
//

import SwiftUI

/// Hosts Home inside its navigation stack, binding the stack to the coordinator.
///
/// The three screens this tab can reach are pushed from here rather than from `HomeView`, which
/// stays a leaf that renders what it is given. All of them go into *this* stack rather than into
/// one of their own — nesting `NavigationStack`s breaks the back gesture and the toolbar both.
/// Each feature's list pushes its own second level into this same stack for the same reason.
///
/// **The toolbar is no longer a holding pattern.** The tab bar took the two things that had
/// outgrown it — the adhkar and, on iOS, Settings — so what is left here is what genuinely
/// belongs in a toolbar: the Qibla, a glance rather than a session, and a small Library menu for
/// the tasbih and the 99 names. Both are visits that end by coming back to Home, which is exactly
/// what a push means and a tab does not. A screen that the user would want to *return* to,
/// finding it where they left it, belongs in `AppTab` instead.
struct HomeCoordinatorView: View {
    @Bindable var coordinator: HomeCoordinator
    let viewModel: HomeViewModel
    let qiblaCoordinator: QiblaCoordinator
    let qiblaViewModel: QiblaViewModel
    let tasbihCoordinator: TasbihCoordinator
    let tasbihViewModel: TasbihViewModel
    let namesCoordinator: NamesCoordinator
    let namesViewModel: NamesViewModel

    /// Where a tap on one of Home's sections goes — which may be another tab entirely. Handed
    /// down from the composition root rather than resolved here; see `AppRoute`.
    let open: (AppRoute) -> Void

    /// The arranging screen, which is Home's own rather than another tab's.
    let customizationViewModel: HomeCustomizationViewModel

    /// The day sheet, which Home puts up over itself.
    let prayerTimesViewModel: PrayerTimesSheetViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(
                viewModel: viewModel,
                open: open,
                showPrayerTimes: { coordinator.isShowingPrayerTimes = true },
                isShowingPrayerTimes: $coordinator.isShowingPrayerTimes,
                customize: { coordinator.show(.customize) }
            )
//                .toolbar { toolbar }
                .navigationDestination(for: HomeCoordinator.Destination.self, destination: destination)
                // How the panel is sized is `PrayerTimesSheet`'s own business — it is the only
                // view that knows how tall its content wants to be, and the answer differs by
                // platform. See the detents and the macOS frame down there.
                .sheet(isPresented: $coordinator.isShowingPrayerTimes) {
                    PrayerTimesSheet(viewModel: prayerTimesViewModel)
                }
        }
    }

    @ViewBuilder
    private func destination(_ destination: HomeCoordinator.Destination) -> some View {
        switch destination {
        case .qibla:
            QiblaView(viewModel: qiblaViewModel, coordinator: qiblaCoordinator)

        case .tasbih:
            TasbihPresetListView(viewModel: tasbihViewModel, coordinator: tasbihCoordinator)

        case .names:
            NamesGridView(viewModel: namesViewModel, coordinator: namesCoordinator)

        case .customize:
            HomeCustomizationView(viewModel: customizationViewModel)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                libraryButton(.tasbih, key: .tasbihTitle, symbol: "circle.hexagonpath")
                libraryButton(.names, key: .namesTitle, symbol: "sparkles")
            } label: {
                Label(l10n.string(.libraryTitle), systemImage: "books.vertical")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                coordinator.show(.qibla)
            } label: {
                Label(l10n.string(.qiblaTitle), systemImage: "location.north.line")
            }
        }
    }

    private func libraryButton(
        _ destination: HomeCoordinator.Destination,
        key: L10nKey,
        symbol: String
    ) -> some View {
        Button {
            coordinator.show(destination)
        } label: {
            Label(l10n.string(key), systemImage: symbol)
        }
    }
}
