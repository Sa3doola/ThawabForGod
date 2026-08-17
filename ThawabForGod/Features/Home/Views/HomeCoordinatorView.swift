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
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
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
