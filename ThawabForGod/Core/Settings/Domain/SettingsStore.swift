//
//  SettingsStore.swift
//  ThawabForGod
//

import Foundation

/// Every user preference the app persists. One list so no layer invents its own key.
nonisolated enum SettingsKey: String, CaseIterable, Sendable {
    case accentPalette
    case appearance
    case language
    case numberSystem
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
}
