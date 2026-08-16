//
//  OnboardingRepositoring.swift
//  ThawabForGod
//

import Foundation

/// Reads and writes the first-run flag and the preferences onboarding seeds.
///
/// Nothing here throws. The store behind it is key/value, where a write cannot meaningfully
/// fail, and inventing an error to catch would only teach the wrong lesson.
nonisolated protocol OnboardingRepositoring: Sendable {
    /// Whether the first run has already been completed. Read once at launch, to route.
    var hasCompletedOnboarding: Bool { get }

    /// The calculation choices onboarding seeded, if it has run.
    var seededConfig: CalculationConfig? { get }

    /// The position onboarding seeded, if it captured one.
    var seededCoordinates: Coordinates? { get }

    /// Writes the seed, then marks onboarding complete.
    ///
    /// The order is part of the contract: the flag goes last, so a run interrupted midway
    /// through never claims a completion it did not finish, and the user simply sees the
    /// first run again.
    func completeOnboarding(with seed: OnboardingSeed)
}
