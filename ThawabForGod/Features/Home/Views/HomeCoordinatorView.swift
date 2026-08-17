//
//  HomeCoordinatorView.swift
//  ThawabForGod
//

import SwiftUI

/// Hosts Home inside its navigation stack, binding the stack to the coordinator.
///
/// Everything else the app can reach is pushed from here rather than from `HomeView`, which stays
/// a leaf that renders what it is given. All of it goes into *this* stack rather than into one of
/// their own — nesting `NavigationStack`s breaks the back gesture and the toolbar both. Each
/// feature's list pushes its own second level into this same stack for the same reason.
///
/// **The toolbar is at its limit and this is a holding pattern.** Four destinations do not fit as
/// four buttons, so the three reading features are grouped behind one menu and Qibla — which is a
/// glance rather than a session — keeps its own button. The real answer is a tab bar, and the
/// next feature that needs reaching from Home is the one that should build it.
///
/// Settings is the exception rather than the fifth item, and deliberately so. It goes at the
/// *leading* edge, opposite the two content buttons, because it is not a destination one browses
/// to — it is the gear every platform puts out of the way of the content. On macOS it is not here
/// at all: that build reaches it through the `Settings` scene and ⌘,. So the trailing group is
/// still the thing a tab bar has to replace, and it has not grown.
struct HomeCoordinatorView: View {
    @Bindable var coordinator: HomeCoordinator
    let viewModel: HomeViewModel
    let qiblaCoordinator: QiblaCoordinator
    let qiblaViewModel: QiblaViewModel
    let adhkarCoordinator: AdhkarCoordinator
    let adhkarViewModel: AdhkarViewModel
    let tasbihCoordinator: TasbihCoordinator
    let tasbihViewModel: TasbihViewModel
    let namesCoordinator: NamesCoordinator
    let namesViewModel: NamesViewModel
    let settingsCoordinator: SettingsCoordinator
    let settingsViewModel: SettingsViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(viewModel: viewModel)
                .toolbar { toolbar }
                .navigationDestination(for: HomeCoordinator.Destination.self, destination: destination)
        }
    }

    @ViewBuilder
    private func destination(_ destination: HomeCoordinator.Destination) -> some View {
        switch destination {
        case .qibla:
            QiblaView(viewModel: qiblaViewModel, coordinator: qiblaCoordinator)

        case .adhkar:
            AdhkarCategoryListView(viewModel: adhkarViewModel, coordinator: adhkarCoordinator)

        case .tasbih:
            TasbihPresetListView(viewModel: tasbihViewModel, coordinator: tasbihCoordinator)

        case .names:
            NamesGridView(viewModel: namesViewModel, coordinator: namesCoordinator)

        case .settings:
            SettingsView(viewModel: settingsViewModel, coordinator: settingsCoordinator)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        #if os(iOS)
        // Leading, and iOS-only: the Mac build reaches Settings through its own scene, so this
        // item would be a second door to the same room.
        ToolbarItem(placement: .topBarLeading) {
            Button {
                coordinator.show(.settings)
            } label: {
                Label(l10n.string(.settingsTitle), systemImage: "gearshape")
            }
        }
        #endif

        ToolbarItem(placement: .primaryAction) {
            Menu {
                libraryButton(.adhkar, key: .adhkarTitle, symbol: "text.book.closed")
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
