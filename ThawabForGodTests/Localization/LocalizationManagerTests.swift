//
//  LocalizationManagerTests.swift
//  ThawabForGodTests
//

import SwiftUI // LayoutDirection; MEMBER_IMPORT_VISIBILITY means it is not re-exported
import Testing
@testable import ThawabForGod

@MainActor
struct LocalizationManagerTests {

    private func makeManager(_ store: InMemorySettingsStore = InMemorySettingsStore()) -> LocalizationManager {
        LocalizationManager(settingsStore: store, numberFormatting: LocaleNumberFormattingService())
    }

    @Test func restoresStoredChoices() {
        let store = InMemorySettingsStore(strings: [
            .language: AppLanguage.arabic.rawValue,
            .numberSystem: NumberSystem.latin.rawValue
        ])

        let manager = makeManager(store)

        #expect(manager.language == .arabic)
        #expect(manager.numberSystem == .latin)
    }

    @Test func unrecognisedStoredValuesFallBack() {
        let store = InMemorySettingsStore(strings: [
            .language: "fr",
            .numberSystem: "roman"
        ])

        let manager = makeManager(store)

        #expect(manager.language == AppLanguage.preferred)
        #expect(manager.numberSystem == NumberSystem.preferred(for: manager.language))
    }

    @Test func selectingALanguagePersistsIt() {
        let store = InMemorySettingsStore()
        let manager = makeManager(store)

        manager.select(language: .arabic)

        #expect(store.string(for: .language) == AppLanguage.arabic.rawValue)
        #expect(makeManager(store).language == .arabic)
    }

    @Test func selectingANumberSystemPersistsIt() {
        let store = InMemorySettingsStore()
        let manager = makeManager(store)

        manager.select(numberSystem: .arabicIndic)

        #expect(store.string(for: .numberSystem) == NumberSystem.arabicIndic.rawValue)
        #expect(makeManager(store).numberSystem == .arabicIndic)
    }

    @Test func languageDrivesLocaleAndLayoutDirection() {
        let manager = makeManager()

        manager.select(language: .arabic)
        #expect(manager.locale.identifier == "ar")
        #expect(manager.layoutDirection == .rightToLeft)

        manager.select(language: .english)
        #expect(manager.locale.identifier == "en")
        #expect(manager.layoutDirection == .leftToRight)
    }

    @Test func numbersFollowTheSelectedSystem() {
        let manager = makeManager()

        manager.select(numberSystem: .arabicIndic)
        #expect(manager.string(7) == "٧")

        manager.select(numberSystem: .latin)
        #expect(manager.string(7) == "7")
    }

    /// End-to-end check that the string catalog actually ships both languages: if Arabic is
    /// missing from the built bundle, this returns the English value and fails.
    @Test func stringsResolveFromTheSelectedLanguageBundle() {
        let manager = makeManager()

        manager.select(language: .english)
        #expect(manager.string(.appName) == "Noor")
        #expect(manager.string(.settingsTitle) == "Settings")

        manager.select(language: .arabic)
        #expect(manager.string(.appName) == "نور")
        #expect(manager.string(.settingsTitle) == "الإعدادات")
    }

    @Test func everyKeyHasATranslationInBothLanguages() {
        let manager = makeManager()

        for language in AppLanguage.allCases {
            manager.select(language: language)
            for key in L10nKey.allCases {
                // A missing key resolves to the key itself.
                #expect(manager.string(key) != key.rawValue, "\(key.rawValue) is missing in \(language.rawValue)")
            }
        }
    }
}
