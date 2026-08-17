//
//  ReminderInputs.swift
//  ThawabForGod
//

import Foundation

/// Everything a refresh needs to know about the world, resolved at the moment it runs.
///
/// Gathered into one value rather than injected as three separate dependencies because all
/// three have to be read *late*: the position can change with the user, the calculation choices
/// can change in Settings, and the toggles can change while the app is open. A service that
/// captured any of them at construction would keep scheduling against a stale answer.
nonisolated struct ReminderInputs: Equatable, Sendable {
    /// Where to compute for, or `nil` if the app does not know where the user is.
    ///
    /// Optional on purpose, and it is the one input that stops a refresh dead. Home falls back
    /// to Makkah so it has something to draw; a reminder cannot do that, because a notification
    /// that fires at Makkah's Maghrib on a phone in London is not a slightly-off reminder — it
    /// is a wrong one, delivered while the user is not looking at the screen to notice. The
    /// same argument the Qibla slice makes for showing nothing rather than pointing confidently
    /// in the wrong direction, only stronger.
    let coordinates: Coordinates?

    let config: CalculationConfig

    let enabledPrayers: Set<Prayer>
}

/// Supplies the state of the world to a refresh.
///
/// `@MainActor` because the concrete implementation reads `LocationService`, which is
/// main-actor isolated for CoreLocation's sake.
@MainActor
protocol ReminderInputsProviding {
    func currentInputs() async -> ReminderInputs
}
