//
//  ThemeManager.swift
//  ThawabForGod
//

import Observation
import SwiftUI

/// Holds the user's theming choices and hands out the resolved `Theme`.
///
/// Main-actor isolated because it exists to drive SwiftUI; `SettingsStore` is `nonisolated`,
/// so persistence stays a plain synchronous call.
@Observable
@MainActor
final class ThemeManager {
    private(set) var accent: AccentPalette
    private(set) var appearance: AppearanceOverride

    @ObservationIgnored private let settingsStore: any SettingsStore

    /// The palette every view reads, with the user's accent applied on top of the defaults.
    var theme: Theme {
        Theme(accent: accent)
    }

    init(settingsStore: any SettingsStore) {
        self.settingsStore = settingsStore
        // An unset or unrecognised stored value falls back rather than trapping.
        self.accent = settingsStore.string(for: .accentPalette)
            .flatMap(AccentPalette.init(rawValue:)) ?? .fallback
        self.appearance = settingsStore.string(for: .appearance)
            .flatMap(AppearanceOverride.init(rawValue:)) ?? .fallback
    }

    func select(accent: AccentPalette) {
        self.accent = accent
        settingsStore.set(accent.rawValue, for: .accentPalette)
    }

    func select(appearance: AppearanceOverride) {
        self.appearance = appearance
        settingsStore.set(appearance.rawValue, for: .appearance)
    }
}
