//
//  OnboardingRepository.swift
//  ThawabForGod
//

import Foundation

/// The first-run flag and seeded preferences, on top of `SettingsStore`.
///
/// `SettingsStore` and not SwiftData: these are user preferences, and the project keeps every
/// preference behind that one store so Settings has a single place to read them from later.
///
/// Note what is *not* written here. `language`, `numberSystem`, `accentPalette` and
/// `appearance` are read by `LocalizationManager` and `ThemeManager`, and onboarding
/// deliberately leaves them unset — see `OnboardingSeed` for why writing a default the user
/// never chose is worse than writing nothing.
nonisolated struct OnboardingRepository: OnboardingRepositoring {
    private let settingsStore: any SettingsStore

    init(settingsStore: any SettingsStore) {
        self.settingsStore = settingsStore
    }

    var hasCompletedOnboarding: Bool {
        settingsStore.bool(for: .onboardingCompleted) ?? false
    }

    // Both read through the shared accessors rather than decoding the keys here: the reminder
    // scheduler needs the same two pairs, and one decode with three readers is the whole point
    // of `SettingsStore+PrayerTimes`.
    var seededConfig: CalculationConfig? { settingsStore.storedCalculationConfig }

    var seededCoordinates: Coordinates? { settingsStore.storedCoordinates }

    func completeOnboarding(with seed: OnboardingSeed) {
        settingsStore.set(seed.config.method.rawValue, for: .calculationMethod)
        settingsStore.set(seed.config.madhab.rawValue, for: .asrMadhab)

        if let coordinates = seed.coordinates {
            settingsStore.set(coordinates.latitude, for: .latitude)
            settingsStore.set(coordinates.longitude, for: .longitude)
        }

        // Last, always. Everything above must already be readable by the time anything is
        // routed past the first run.
        settingsStore.set(true, for: .onboardingCompleted)
    }
}
