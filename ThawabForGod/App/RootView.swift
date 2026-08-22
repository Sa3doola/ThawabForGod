//
//  RootView.swift
//  ThawabForGod
//

import SwiftUI

/// The app's first branch: onboarding, or the main interface.
///
/// A `switch` over the router's destination — no `AnyView`, and no conditional modifier that
/// would leave both branches half-alive. What the main interface *looks* like — a tab bar or a
/// sidebar, depending on how wide the window is — is `MainInterfaceView`'s business, and this
/// view stays about the branch.
///
/// It is also where the reminder window is kept filled, because the composition root is the only
/// layer entitled to know that a preference change and a notification schedule have anything to
/// do with each other. Both triggers hang off the `.home` branch on purpose: reminders are
/// meaningless until onboarding has produced a position and a calculation method, and evaluating
/// the key earlier would build `CalculationSettings` before onboarding had seeded it.
///
/// On iOS, every foreground refill also books the next background top-up through
/// `BackgroundRefreshScheduler`, so a phone that is never reopened still gets refilled — see
/// that type's documentation for the one manual Xcode step it depends on.
///
/// It is also where links from outside the app land, for the same reason: a `noor://` URL, a
/// quick action and a Dock menu item all name a section, and the composition root is the only
/// layer entitled to move between them. Both arrive on the `.home` branch only — a link during
/// onboarding is dropped rather than queued, because there is no interface yet for it to open.
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
            MainInterfaceView(container: container)
            // Runs once when this branch appears — which covers both launching into Home and
            // arriving from the last step of onboarding — and again whenever anything the
            // pending reminders were built from changes.
            .task(id: reminderKey) { await refillReminders() }
            // And on every return to the foreground, which is what keeps a ten-day window from
            // running dry between launches.
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await refillReminders() }
            }
            // Widget taps and `noor://` URLs. SwiftUI delivers these straight to the view tree
            // on both platforms, so no delegate is involved — a URL that names nothing this
            // build understands decodes to `nil` and is ignored.
            .onOpenURL { url in
                guard let link = DeepLink(url: url) else { return }
                container.open(link)
            }
            // Quick actions, which do not come through `onOpenURL`. `initial: true` is what
            // covers the cold-launch case: the scene delegate posts the link before this view
            // has a body, so there is no *change* to observe — only a value already waiting.
            .onChange(of: container.deepLinks.pending, initial: true) { _, _ in
                guard let link = container.deepLinks.consume() else { return }
                container.open(link)
            }
            #if os(iOS)
            // Registered on the way in and again on the way out. The system stores the finished
            // titles, so this has to run at least once per launch to be right in the language
            // the process is actually running in.
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active || phase == .background else { return }
                QuickActionsService(localization: container.localizationManager).register()
            }
            #endif
        }
    }

    /// Refills the pending window, then — on iOS — books the next background top-up so the
    /// window keeps refilling even if the app is never reopened.
    private func refillReminders() async {
        await container.notificationService.refreshSchedule()
        #if os(iOS)
        container.backgroundRefreshScheduler.scheduleNextRefresh()
        #endif
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
