//
//  AppRouter.swift
//  ThawabForGod
//

import Observation

/// Decides what the app shows at launch, and moves on when the first run ends.
///
/// The decision is made once, from the persisted completion flag, rather than re-read on
/// every redraw — so a user who finishes onboarding does not risk being sent back to it by a
/// stale read, and a user who has onboarded never sees a flash of the welcome screen.
@Observable
@MainActor
final class AppRouter {
    enum Destination: Equatable {
        case onboarding
        case home
    }

    private(set) var destination: Destination

    init(hasCompletedOnboarding: Bool) {
        destination = hasCompletedOnboarding ? .home : .onboarding
    }

    func onboardingFinished() {
        destination = .home
    }
}
