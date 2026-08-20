//
//  PrayerCalculationSettingsViewModel.swift
//  ThawabForGod
//

import Observation

/// How the prayer times are worked out.
///
/// These edit the *same* preferences onboarding asked about, through the same
/// `CalculationSettings` object Home computes from — not a copy. That is what makes a change here
/// reach the times immediately: Home watches the config it was given and recomputes when it
/// differs, so a reader who changes the method finds today's times already redrawn when they go
/// back.
@Observable
@MainActor
final class PrayerCalculationSettingsViewModel {

    /// Whether the reset confirmation is up. The one piece of state this screen owns — a
    /// destructive action's confirmation is not something a scroll should be able to dismiss.
    var isConfirmingReset = false

    @ObservationIgnored private let calculation: CalculationSettings

    init(calculation: CalculationSettings) {
        self.calculation = calculation
    }

    var method: PrayerCalculationMethod {
        get { calculation.config.method }
        set { calculation.select(method: newValue) }
    }

    var madhab: AsrMadhab {
        get { calculation.config.madhab }
        set { calculation.select(madhab: newValue) }
    }

    /// Whether anything has been moved off the defaults — what the reset row is enabled by.
    var hasChoices: Bool {
        calculation.config != .default
    }

    func reset() {
        calculation.reset()
    }
}
