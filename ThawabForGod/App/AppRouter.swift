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

    /// Which tab the main interface is showing.
    ///
    /// Here rather than in a `@State` on `MainTabView` because tab selection is app-level
    /// routing, not view state: it is what a later slice — a tapped reminder, a widget, a
    /// deep link — has to be able to set without reaching into the view hierarchy. Settable
    /// rather than `private(set)` because the `TabView` itself writes it through a binding.
    var selectedTab: AppTab = .home

    init(hasCompletedOnboarding: Bool) {
        destination = hasCompletedOnboarding ? .home : .onboarding
    }

    func onboardingFinished() {
        destination = .home
    }
}
