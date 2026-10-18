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
}
