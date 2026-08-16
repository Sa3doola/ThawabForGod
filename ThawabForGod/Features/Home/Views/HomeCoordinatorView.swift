//
//  HomeCoordinatorView.swift
//  ThawabForGod
//

import SwiftUI

/// Hosts Home inside its navigation stack, binding the stack to the coordinator.
///
/// No `navigationDestination` is registered yet because Home has nowhere to push to. This is
/// the file that grows one when the first destination arrives — `HomeView` itself stays a
/// leaf that renders what it is given.
struct HomeCoordinatorView: View {
    @Bindable var coordinator: HomeCoordinator
    let viewModel: HomeViewModel

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(viewModel: viewModel)
        }
    }
}
