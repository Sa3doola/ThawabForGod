//
//  ReminderContentProviding.swift
//  ThawabForGod
//

import Foundation

/// The words a reminder shows.
nonisolated struct ReminderContent: Equatable, Sendable {
    let title: String
    let body: String
}

/// Resolves a prayer into the text its reminder carries.
///
/// A seam rather than a call to `LocalizationManager` inside the scheduler, for a reason worth
/// stating: notification text is baked in **when the reminder is scheduled**, not when it is
/// delivered. A pending reminder therefore keeps whatever language was in effect at its last
/// refresh, which is why a language change has to trigger a refresh like a method change does.
/// Naming the seam is what makes that dependency visible instead of buried.
///
/// Nothing about the user goes in here — a prayer name and a fixed sentence, both localized.
/// A notification is shown on a locked screen to whoever is holding the phone.
@MainActor
protocol ReminderContentProviding {
    func content(for prayer: Prayer) -> ReminderContent
}
