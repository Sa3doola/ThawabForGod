//
//  WidgetStyle.swift
//  ThawabForGod
//

import Foundation

extension NextPrayerSnapshot.Style {

    /// The presentation choices (digits, clock, accent, language) as the App Group holds them,
    /// with the same fallbacks everywhere a widget reads them.
    nonisolated static func current(from settingsStore: any SettingsStore) -> Self {
        let language = AppLanguage.current()

        return Self(
            numberSystem: settingsStore.string(for: .numberSystem)
                .flatMap(NumberSystem.init(rawValue:)) ?? .preferred(for: language),
            clockFormat: settingsStore.string(for: .clockFormat)
                .flatMap(ClockFormat.init(rawValue:)) ?? .fallback,
            accent: settingsStore.string(for: .accentPalette)
                .flatMap(AccentPalette.init(rawValue:)) ?? .fallback,
            language: language
        )
    }

    /// The style a preview draws with: the device's language and the defaults, read from nothing
    /// shared. A gallery render has no business waiting on the App Group.
    nonisolated static func preview() -> Self {
        let language = AppLanguage.current()
        return Self(numberSystem: .preferred(for: language), clockFormat: .fallback, accent: .fallback, language: language)
    }
}
