//
//  AppContainer.swift
//  ThawabForGod
//

import Foundation

/// Composition root. The only place concrete implementations are constructed — everything
/// else depends on protocols and receives them through init or the environment.
@MainActor
final class AppContainer {
    let settingsStore: any SettingsStore
    let themeManager: ThemeManager

    init(settingsStore: any SettingsStore = UserDefaultsSettingsStore()) {
        self.settingsStore = settingsStore
        self.themeManager = ThemeManager(settingsStore: settingsStore)
    }
}
