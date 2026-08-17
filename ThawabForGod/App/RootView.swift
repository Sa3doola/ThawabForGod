//
//  RootView.swift
//  ThawabForGod
//

import SwiftUI

/// The app's first branch: onboarding, or the main interface.
///
/// A `switch` over the router's destination — no `AnyView`, and no conditional modifier that
/// would leave both branches half-alive.
struct RootView: View {
    let container: AppContainer

    var body: some View {
        switch container.router.destination {
        case .onboarding:
            OnboardingContainerView(
                viewModel: container.onboardingViewModel,
                coordinator: container.onboardingCoordinator
            )

        case .home:
            HomeCoordinatorView(
                coordinator: container.homeCoordinator,
                viewModel: container.homeViewModel(),
                qiblaCoordinator: container.qiblaCoordinator,
                qiblaViewModel: container.qiblaViewModel(),
                adhkarCoordinator: container.adhkarCoordinator,
                adhkarViewModel: container.adhkarViewModel()
            )
        }
    }
}
