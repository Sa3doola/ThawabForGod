//
//  ThemeManagerTests.swift
//  ThawabForGodTests
//

import SwiftUI // ColorScheme; MEMBER_IMPORT_VISIBILITY means it is not re-exported
import Testing
@testable import ThawabForGod

@MainActor
struct ThemeManagerTests {

    @Test func fallsBackToDefaultAccentWhenNothingIsStored() {
        let manager = ThemeManager(settingsStore: InMemorySettingsStore())

        #expect(manager.accent == .amber)
        #expect(manager.appearance == .system)
    }

    @Test func restoresStoredChoices() {
        let store = InMemorySettingsStore(strings: [
            .accentPalette: AccentPalette.sapphire.rawValue,
            .appearance: AppearanceOverride.dark.rawValue
        ])

        let manager = ThemeManager(settingsStore: store)

        #expect(manager.accent == .sapphire)
        #expect(manager.appearance == .dark)
    }

    @Test func unrecognisedStoredValuesFallBack() {
        let store = InMemorySettingsStore(strings: [
            .accentPalette: "chartreuse",
            .appearance: "sepia"
        ])

        let manager = ThemeManager(settingsStore: store)

        #expect(manager.accent == .amber)
        #expect(manager.appearance == .system)
    }

    @Test func selectingAnAccentOverridesTheThemeAccent() {
        let manager = ThemeManager(settingsStore: InMemorySettingsStore())
        #expect(manager.theme.accent == AppColor.accent(.amber))

        manager.select(accent: .rose)

        #expect(manager.theme.accent == AppColor.accent(.rose))
        // The rest of the palette is untouched by the accent choice.
        #expect(manager.theme.primary == AppColor.primary)
    }

    @Test func selectingAnAccentPersistsIt() {
        let store = InMemorySettingsStore()
        let manager = ThemeManager(settingsStore: store)

        manager.select(accent: .emerald)

        #expect(store.string(for: .accentPalette) == AccentPalette.emerald.rawValue)
        #expect(ThemeManager(settingsStore: store).accent == .emerald)
    }

    @Test func selectingAnAppearancePersistsIt() {
        let store = InMemorySettingsStore()
        let manager = ThemeManager(settingsStore: store)

        manager.select(appearance: .light)

        #expect(store.string(for: .appearance) == AppearanceOverride.light.rawValue)
        #expect(ThemeManager(settingsStore: store).appearance == .light)
    }

    @Test(arguments: AppearanceOverride.allCases)
    func appearanceMapsToColorScheme(_ appearance: AppearanceOverride) {
        switch appearance {
        case .system: #expect(appearance.colorScheme == nil)
        case .light: #expect(appearance.colorScheme == .light)
        case .dark: #expect(appearance.colorScheme == .dark)
        }
    }
}
