//
//  AppearanceSettingsViewModel.swift
//  ThawabForGod
//

import Observation

/// The accent and the light/dark choice.
///
/// **It stores nothing.** Both preferences already belong to `ThemeManager`, which persists them
/// through `SettingsStore` and is applied once at the root — so this forwards rather than mirrors.
/// A second copy of the accent living here would be a second source of truth, and the two would
/// drift the first time anything else changed one.
///
/// That is also why the properties are computed with setters rather than stored: reading one
/// inside a view registers an observation dependency on the *owner*, so a picker bound to it both
/// writes through and re-renders when anything else changes it.
@Observable
@MainActor
final class AppearanceSettingsViewModel {
    @ObservationIgnored private let theme: ThemeManager

    init(theme: ThemeManager) {
        self.theme = theme
    }

    var accent: AccentPalette {
        get { theme.accent }
        set { theme.select(accent: newValue) }
    }

    var appearance: AppearanceOverride {
        get { theme.appearance }
        set { theme.select(appearance: newValue) }
    }
}
