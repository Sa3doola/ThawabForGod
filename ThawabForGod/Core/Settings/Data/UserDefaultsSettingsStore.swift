//
//  UserDefaultsSettingsStore.swift
//  ThawabForGod
//

import Foundation

/// `UserDefaults`-backed settings. A value type over a thread-safe store, so it is `Sendable`
/// without any locking of our own.
nonisolated struct UserDefaultsSettingsStore: SettingsStore {
    /// Safety invariant: `UserDefaults` is documented as thread-safe, but is not marked
    /// `Sendable` by Foundation. Nothing here mutates the reference itself.
    nonisolated(unsafe) private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(for key: SettingsKey) -> String? {
        defaults.string(forKey: key.rawValue)
    }

    func set(_ value: String?, for key: SettingsKey) {
        if let value {
            defaults.set(value, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    func bool(for key: SettingsKey) -> Bool? {
        // `bool(forKey:)` cannot distinguish "false" from "unset".
        defaults.object(forKey: key.rawValue) as? Bool
    }

    func set(_ value: Bool?, for key: SettingsKey) {
        if let value {
            defaults.set(value, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}
