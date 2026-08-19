//
//  AppRoutingTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Launch routing: the one decision that decides whether a returning user is sent back
/// through the first run.
@MainActor
struct AppRoutingTests {

    @Test func aFreshInstallRoutesToOnboarding() {
        let router = AppRouter(hasCompletedOnboarding: false)

        #expect(router.destination == .onboarding)
    }

    @Test func aCompletedOnboardingRoutesStraightToHome() {
        let router = AppRouter(hasCompletedOnboarding: true)

        #expect(router.destination == .home)
    }

    @Test func finishingOnboardingHandsOverToHome() {
        let router = AppRouter(hasCompletedOnboarding: false)

        router.onboardingFinished()

        #expect(router.destination == .home)
    }

    // MARK: Through the container

    private func makeContainer(settingsStore: InMemorySettingsStore) throws -> AppContainer {
        AppContainer(
            settingsStore: settingsStore,
            persistence: try PersistenceController(inMemory: true),
            locationService: MockLocationService(),
            notificationService: MockNotificationService(),
            // `BGTaskScheduler.shared.register(_:)` is a real system call with no fake to hand
            // it instead — see the parameter's own documentation on `AppContainer.init`.
            registersBackgroundRefresh: false
        )
    }

    @Test func theContainerRoutesFromThePersistedFlag() throws {
        let fresh = try makeContainer(settingsStore: InMemorySettingsStore())
        #expect(fresh.router.destination == .onboarding)

        let returning = try makeContainer(
            settingsStore: InMemorySettingsStore(bools: [.onboardingCompleted: true])
        )
        #expect(returning.router.destination == .home)
    }

    /// The coordinator is what closes the loop: finishing the flow has to move the router,
    /// or the user would sit on a finished onboarding screen forever.
    @Test func completingTheFlowMovesTheContainersRouterToHome() throws {
        let container = try makeContainer(settingsStore: InMemorySettingsStore())

        for _ in OnboardingStep.visibleSteps {
            container.onboardingCoordinator.advance()
        }

        #expect(container.onboardingViewModel.isFinished)
        #expect(container.router.destination == .home)
    }

    /// Home must be built from what onboarding just seeded, not from the defaults that were
    /// in place at launch — which is why its view model is created lazily.
    @Test func homeIsBuiltFromTheSeededConfiguration() throws {
        let store = InMemorySettingsStore()
        let container = try makeContainer(settingsStore: store)

        container.onboardingViewModel.select(method: .karachi)
        container.onboardingViewModel.select(madhab: .hanafi)
        for _ in OnboardingStep.visibleSteps {
            container.onboardingCoordinator.advance()
        }

        #expect(container.onboardingRepository.seededConfig == CalculationConfig(method: .karachi, madhab: .hanafi))
        // Built only now, after the seed was written.
        #expect(container.homeViewModel().phase == .loading)
    }

    @Test func homeViewModelIsBuiltOnceAndKept() throws {
        let container = try makeContainer(
            settingsStore: InMemorySettingsStore(bools: [.onboardingCompleted: true])
        )

        #expect(container.homeViewModel() === container.homeViewModel())
    }
}
