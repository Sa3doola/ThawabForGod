//
//  AppReminderInputs.swift
//  ThawabForGod
//

import Foundation

/// Gathers the position, the calculation choices and the toggles at the moment a refresh runs.
///
/// The position is the interesting part. It prefers a live reading, because a user who has
/// travelled since onboarding should be reminded for where they are now — but a fix costs a
/// round trip to CoreLocation and can fail for reasons that have nothing to do with the user,
/// so the last position the app resolved stands behind it, and what onboarding captured behind
/// that. If none of the three answers, `coordinates` is `nil` and
/// the refresh schedules nothing at all; see `ReminderInputs` for why that is better than
/// falling back to Makkah the way Home does.
///
/// The other two are read straight from the store rather than from `CalculationSettings` and
/// `ReminderPreferences`. Those own the in-memory copy and write through on every change, so the
/// store is never behind them — and reading it here keeps this type free of a construction-order
/// dependency on a manager the composition root builds lazily.
@MainActor
struct AppReminderInputs: ReminderInputsProviding {
    private let location: any LocationService
    private let settingsStore: any SettingsStore

    init(location: any LocationService, settingsStore: any SettingsStore) {
        self.location = location
        self.settingsStore = settingsStore
    }

    func currentInputs() async -> ReminderInputs {
        ReminderInputs(
            coordinates: await resolvedCoordinates(),
            // `.default` only matters before onboarding has run, and at that point there are no
            // coordinates either — so it never actually schedules anything.
            config: settingsStore.storedCalculationConfig ?? .default,
            enabledPrayers: settingsStore.enabledReminderPrayers
        )
    }

    private func resolvedCoordinates() async -> Coordinates? {
        // Asked only when already granted: `currentCoordinates()` on an undetermined permission
        // would put a system prompt in front of someone who has just opened the app, which is
        // not a thing a background refresh may do.
        if location.authorization == .authorized,
           let live = try? await location.currentCoordinates() {
            return live
        }

        // Not `storedCoordinates`: a user who has travelled since onboarding and whose fix has
        // just failed is better served by where the app last saw them than by where they said
        // they were months ago. `CoreLocationService` keeps that cache; nothing here writes it.
        return settingsStore.bestKnownCoordinates
    }
}
