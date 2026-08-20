//
//  SettingsStore.swift
//  ThawabForGod
//

import Foundation

/// Every user preference the app persists. One list so no layer invents its own key.
nonisolated enum SettingsKey: String, CaseIterable, Sendable {
    case accentPalette
    case appearance
    // No `language`: it is the system's, chosen in the app's own page in the Settings app. A key
    // here would outrank that choice forever, which is the exact failure the note above
    // describes — and it is why an in-app switcher was removed rather than repaired.
    case numberSystem
    case clockFormat

    // Seeded by onboarding, read from then on by prayer times, Settings and the reminders.
    case onboardingCompleted
    case calculationMethod
    case asrMadhab
    case latitude
    case longitude

    // How Home is arranged: which sections, in what order, and which shortcut circles. One key
    // holding the whole value as JSON — see `HomeLayoutRepository` for why it is not nine.
    case homeLayout

    // The reading screen's own look. Unset means the app's colours at the app's size — the
    // reader has to have opened the panel and moved something for any of these to exist, which
    // is what lets "reset" write `nil` back rather than the defaults.
    case readerPaper
    case readerTextSize
    case readerLineSpacing

    // One per obligatory prayer. Unset means on — a reminder the user has never opinionated
    // about should arrive, and writing `true` at first launch would breach the rule above.
    case reminderFajr
    case reminderDhuhr
    case reminderAsr
    case reminderMaghrib
    case reminderIsha
}

/// Small key/value store for user preferences.
///
/// `nonisolated` is explicit: the module default is `MainActor`, but persistence and
/// networking read settings off the main actor.
nonisolated protocol SettingsStore: Sendable {
    func string(for key: SettingsKey) -> String?
    func set(_ value: String?, for key: SettingsKey)

    func bool(for key: SettingsKey) -> Bool?
    func set(_ value: Bool?, for key: SettingsKey)

    func double(for key: SettingsKey) -> Double?
    func set(_ value: Double?, for key: SettingsKey)
}
