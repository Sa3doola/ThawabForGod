//
//  HomeCoordinatorView.swift
//  ThawabForGod
//

import SwiftUI

/// Hosts Home inside its navigation stack, binding the stack to the coordinator.
///
/// Qibla and the adhkar are reached from here rather than from `HomeView`, which stays a leaf
/// that renders what it is given. Both are pushed into *this* stack rather than wrapped in one
/// of their own — nesting `NavigationStack`s breaks the back gesture and the toolbar both. The
/// adhkar list pushes its own second level into this same stack for the same reason.
struct HomeCoordinatorView: View {
    @Bindable var coordinator: HomeCoordinator
    let viewModel: HomeViewModel
    let qiblaCoordinator: QiblaCoordinator
    let qiblaViewModel: QiblaViewModel
    let adhkarCoordinator: AdhkarCoordinator
    let adhkarViewModel: AdhkarViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(viewModel: viewModel)
                .toolbar { toolbar }
                .navigationDestination(for: HomeCoordinator.Destination.self) { destination in
                    switch destination {
                    case .qibla:
                        QiblaView(viewModel: qiblaViewModel, coordinator: qiblaCoordinator)

                    case .adhkar:
                        AdhkarCategoryListView(
                            viewModel: adhkarViewModel,
                            coordinator: adhkarCoordinator
                        )
                    }
                }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                coordinator.show(.adhkar)
            } label: {
                Label(l10n.string(.adhkarTitle), systemImage: "text.book.closed")
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
}
