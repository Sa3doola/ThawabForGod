//
//  BackgroundRefreshSchedulerTests.swift
//  ThawabForGodTests
//

#if os(iOS)
import Foundation
import Testing
@testable import ThawabForGod

/// Publishing the scheduler that the background launch handler runs.
///
/// Not tested here, and deliberately: `BackgroundRefreshScheduler.registerLaunchHandler()`. The
/// system allows one registration per identifier per process, and only before launch finishes, so
/// calling it from a test would crash the test host. That the handler is registered before launch
/// finishes is a property of the launch sequence and is verified by launching the app, not by a
/// unit test.
///
/// `.serialized` because `BackgroundRefreshScheduler.current` is process-wide state: two tests
/// publishing at once would see each other's scheduler.
@Suite(.serialized)
@MainActor
struct BackgroundRefreshSchedulerTests {

    /// Same construction as every other test that builds a container, so these tests see the
    /// container the rest of the suite sees. Only `registersBackgroundRefresh` varies. Building
    /// with `true` is safe in a test: the container only publishes its scheduler, and it no longer
    /// calls into `BGTaskScheduler`, which happens in the app delegate's launch callback.
    private func makeContainer(registersBackgroundRefresh: Bool = false) throws -> AppContainer {
        AppContainer(
            settingsStore: InMemorySettingsStore(bools: [.onboardingCompleted: true]),
            persistence: try PersistenceController(inMemory: true),
            locationService: MockLocationService(),
            notificationService: MockNotificationService(),
            registersBackgroundRefresh: registersBackgroundRefresh
        )
    }

    @Test func makeCurrentPublishesTheInstanceItIsGiven() {
        // `current` has a private setter and no way to clear it, so a test cannot assign `nil`.
        // Restore what was there before, if anything was. The host app's own container publishes
        // its scheduler when its scene connects, so `current` is normally non-nil by the time a
        // test runs and the `defer` puts it back. If it is still `nil` (no scene has connected
        // yet, or none ever will), the scheduler left behind was built over a fake notification
        // service and can do no harm, and the host's container publishes over it if a scene
        // connects later. The type deliberately offers no way to clear it.
        let saved = BackgroundRefreshScheduler.current
        defer {
            if let saved {
                BackgroundRefreshScheduler.makeCurrent(saved)
            }
        }

        let scheduler = BackgroundRefreshScheduler(notificationService: MockNotificationService())

        BackgroundRefreshScheduler.makeCurrent(scheduler)

        #expect(BackgroundRefreshScheduler.current === scheduler)
    }

    /// The container only publishes when asked to. Built with the flag off, it must leave
    /// `current` pointing at something other than its own scheduler, so a test container can never
    /// become the target of the host app's handler.
    @Test func aContainerBuiltWithBackgroundRefreshOffDoesNotPublishItsScheduler() throws {
        let container = try makeContainer(registersBackgroundRefresh: false)

        #expect(BackgroundRefreshScheduler.current !== container.backgroundRefreshScheduler)
    }

    /// The production branch. Without this, deleting the `makeCurrent` call in `AppContainer.init`
    /// would leave every test green while background refresh silently did nothing. Save and
    /// restore follow the same rule as `makeCurrentPublishesTheInstanceItIsGiven`.
    @Test func aContainerBuiltWithBackgroundRefreshOnPublishesItsScheduler() throws {
        let saved = BackgroundRefreshScheduler.current
        defer {
            if let saved {
                BackgroundRefreshScheduler.makeCurrent(saved)
            }
        }

        let container = try makeContainer(registersBackgroundRefresh: true)

        #expect(BackgroundRefreshScheduler.current === container.backgroundRefreshScheduler)
    }
}
#endif
