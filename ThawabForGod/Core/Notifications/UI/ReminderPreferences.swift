//
//  ReminderPreferences.swift
//  ThawabForGod
//

import Observation

/// Which prayers the user wants reminding of.
///
/// The sibling of `ThemeManager`, `LocalizationManager` and `CalculationSettings`, and here for
/// the same reason they are: the choice has to be observable, because Settings edits it and the
/// scheduler reads it. Persisted through `SettingsStore` under one key per prayer.
///
/// **Unset means on.** A user who has never opened this screen should still be reminded, and
/// writing `true` for five keys at first launch would be exactly the "persisting a default turns
/// it into a choice" mistake the store's own notes warn about. So nothing is written until a
/// toggle is actually moved.
@Observable
@MainActor
final class ReminderPreferences {

    /// The prayers currently switched on. A set rather than five properties, because that is
    /// what the planner takes and what the refresh key compares.
    private(set) var enabledPrayers: Set<Prayer>

    @ObservationIgnored private let settingsStore: any SettingsStore

    init(settingsStore: any SettingsStore) {
        self.settingsStore = settingsStore
        self.enabledPrayers = settingsStore.enabledReminderPrayers
    }

    func isEnabled(_ prayer: Prayer) -> Bool {
        enabledPrayers.contains(prayer)
    }

    func setEnabled(_ isEnabled: Bool, for prayer: Prayer) {
        guard let key = prayer.reminderSettingsKey else { return }

        if isEnabled {
            enabledPrayers.insert(prayer)
        } else {
            enabledPrayers.remove(prayer)
        }

        settingsStore.set(isEnabled, for: key)
    }
}
