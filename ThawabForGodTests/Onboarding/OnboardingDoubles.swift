//
//  OnboardingDoubles.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// A location service that answers however the test needs it to, and records that it was asked.
@MainActor
final class MockLocationService: LocationService {
    var authorization: LocationAuthorization
    var coordinatesResult: Result<Coordinates, Error>

    private(set) var authorizationRequestCount = 0
    private(set) var coordinatesRequestCount = 0

    /// The status the prompt resolves to. Applied to `authorization` when asked, so a test
    /// reads the same "before and after" the real service would produce.
    var outcomeOfPrompt: LocationAuthorization

    init(
        authorization: LocationAuthorization = .notDetermined,
        outcomeOfPrompt: LocationAuthorization = .authorized,
        coordinatesResult: Result<Coordinates, Error> = .success(Coordinates(latitude: 51.5, longitude: -0.12))
    ) {
        self.authorization = authorization
        self.outcomeOfPrompt = outcomeOfPrompt
        self.coordinatesResult = coordinatesResult
    }

    @discardableResult
    func requestWhenInUseAuthorization() async -> LocationAuthorization {
        authorizationRequestCount += 1
        authorization = outcomeOfPrompt
        return authorization
    }

    func currentCoordinates() async throws -> Coordinates {
        coordinatesRequestCount += 1
        return try coordinatesResult.get()
    }
}

/// Records what onboarding wrote, without touching `UserDefaults`.
///
/// Safety invariant for `@unchecked Sendable`: only ever touched from the test's main actor.
/// The protocol is `nonisolated` because production writes go through a `nonisolated` store.
nonisolated final class SpyOnboardingRepository: OnboardingRepositoring, @unchecked Sendable {
    private(set) var savedSeed: OnboardingSeed?
    private var completed: Bool

    init(hasCompletedOnboarding: Bool = false) {
        self.completed = hasCompletedOnboarding
    }

    var hasCompletedOnboarding: Bool { completed }

    var seededConfig: CalculationConfig? { savedSeed?.config }

    var seededCoordinates: Coordinates? { savedSeed?.coordinates }

    func completeOnboarding(with seed: OnboardingSeed) {
        savedSeed = seed
        completed = true
    }
}
