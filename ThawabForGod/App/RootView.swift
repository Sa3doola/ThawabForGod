//
//  RootView.swift
//  ThawabForGod
//

import SwiftUI

/// The app's first branch: onboarding, or the main interface.
///
/// A `switch` over the router's destination — no `AnyView`, and no conditional modifier that
/// would leave both branches half-alive.
///
/// It is also where the reminder window is kept filled, because the composition root is the only
/// layer entitled to know that a preference change and a notification schedule have anything to
/// do with each other. Both triggers hang off the `.home` branch on purpose: reminders are
/// meaningless until onboarding has produced a position and a calculation method, and evaluating
/// the key earlier would build `CalculationSettings` before onboarding had seeded it.
struct RootView: View {
    let container: AppContainer

    @Environment(\.scenePhase) private var scenePhase

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
                adhkarViewModel: container.adhkarViewModel(),
                tasbihCoordinator: container.tasbihCoordinator,
                tasbihViewModel: container.tasbihViewModel(),
                namesCoordinator: container.namesCoordinator,
                namesViewModel: container.namesViewModel(),
                settingsCoordinator: container.settingsCoordinator,
                settingsViewModel: container.settingsViewModel()
            )
            // Runs once when this branch appears — which covers both launching into Home and
            // arriving from the last step of onboarding — and again whenever anything the
            // pending reminders were built from changes.
            .task(id: reminderKey) { await container.notificationService.refreshSchedule() }
            // And on every return to the foreground, which is what keeps a ten-day window from
            // running dry. A phone left closed for longer needs `BGTaskScheduler`; see the note
            // at the foot of `UserNotificationService`.
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await container.notificationService.refreshSchedule() }
            }
        }
    }

    /// Everything a pending reminder was built from. When any part of it changes, the window on
    /// the system is out of date and has to be rebuilt.
    ///
    /// Notification text is resolved when a reminder is *scheduled*, so the language matters as
    /// much as the times do — but it is not in this key, because it cannot change without the
    /// system relaunching the app. A relaunch runs this task from scratch, which reschedules the
    /// whole window in the new language on its own.
    private var reminderKey: ReminderRefreshKey {
        ReminderRefreshKey(
            config: container.calculationSettings().config,
            enabledPrayers: container.reminderPreferences.enabledPrayers
        )
    }
}

/// `Equatable` rather than `Hashable` because that is all `task(id:)` asks for.
private struct ReminderRefreshKey: Equatable {
    let config: CalculationConfig
    let enabledPrayers: Set<Prayer>
}
