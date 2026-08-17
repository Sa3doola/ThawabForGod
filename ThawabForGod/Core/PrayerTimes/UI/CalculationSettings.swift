//
//  CalculationSettings.swift
//  ThawabForGod
//

import Observation

/// The user's prayer-calculation choices, live.
///
/// The sibling of `ThemeManager` and `LocalizationManager`, and here for the same reason: the
/// choice has to be *observable*, because two screens act on it at once — Settings edits it and
/// Home recomputes from it. Before this existed, `CalculationConfig` was read once at launch and
/// handed to `HomeViewModel` as a stored constant, which is exactly what a Settings screen cannot
/// work with.
///
/// It writes the same two `SettingsKey`s onboarding seeds, rather than a second pair of its own —
/// so changing the method in Settings edits the first run's answer instead of shadowing it.
///
/// `@MainActor` because it is read during view updates and written from a picker; the store
/// behind it is `nonisolated`, so persisting stays a plain synchronous call.
@Observable
@MainActor
final class CalculationSettings {
    private(set) var config: CalculationConfig

    @ObservationIgnored private let settingsStore: any SettingsStore

    /// - Parameter config: the starting value, read by the composition root from what onboarding
    ///   seeded. Injected rather than decoded here so the two keys have one reader
    ///   (`OnboardingRepository`) and this type owns only the edits.
    init(config: CalculationConfig, settingsStore: any SettingsStore) {
        self.config = config
        self.settingsStore = settingsStore
    }

    func select(method: PrayerCalculationMethod) {
        config.method = method
        settingsStore.set(method.rawValue, for: .calculationMethod)
    }

    func select(madhab: AsrMadhab) {
        config.madhab = madhab
        settingsStore.set(madhab.rawValue, for: .asrMadhab)
    }
}
