//
//  InMemorySettingsStore.swift
//  ThawabForGod
//

import Foundation

/// Non-persisting settings store for previews and tests.
///
/// Lives in the app target (not the test target) so previews can use it too.
///
/// Safety invariant for `@unchecked Sendable`: `strings` and `bools` are only ever touched
/// while `lock` is held, and nothing else escapes. `Mutex` would express this in the type
/// system but is iOS 18+; this app targets iOS 17.
nonisolated final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var strings: [SettingsKey: String] = [:]
    private var bools: [SettingsKey: Bool] = [:]

    init(strings: [SettingsKey: String] = [:], bools: [SettingsKey: Bool] = [:]) {
        self.strings = strings
        self.bools = bools
    }

    func string(for key: SettingsKey) -> String? {
        lock.withLock { strings[key] }
    }

    func set(_ value: String?, for key: SettingsKey) {
        lock.withLock { strings[key] = value }
    }

    func bool(for key: SettingsKey) -> Bool? {
        lock.withLock { bools[key] }
    }

    func set(_ value: Bool?, for key: SettingsKey) {
        lock.withLock { bools[key] = value }
    }
}
