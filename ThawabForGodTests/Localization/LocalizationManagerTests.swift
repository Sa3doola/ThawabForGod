//
//  LocalizationManagerTests.swift
//  ThawabForGodTests
//

import Foundation
import SwiftUI // LayoutDirection; MEMBER_IMPORT_VISIBILITY means it is not re-exported
import Testing
@testable import ThawabForGod

@MainActor
struct LocalizationManagerTests {

    /// - Parameter language: injected rather than taken from the test host's bundle. The app
    ///   reads it from the process, which a test cannot change — so the seam that makes it
    ///   testable is the same one that documents where it really comes from.
    private func makeManager(
        _ store: InMemorySettingsStore = InMemorySettingsStore(),
        language: AppLanguage = .english
    ) -> LocalizationManager {
        LocalizationManager(
            settingsStore: store,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService(),
            language: language
        )
    }

    /// The catalog for one language, read straight from the built bundle.
    ///
    /// The coverage test below used to go through the manager, which could switch languages at
    /// runtime. It cannot any more — the process launches in one language and stays there — so
    /// the catalog is checked directly. That is the more honest target anyway: what is under
    /// test is whether the translations shipped, not whether the manager can reach them.
    private func catalog(for language: AppLanguage) throws -> Bundle {
        let path = try #require(
            Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
            "\(language.rawValue).lproj is missing from the built bundle"
        )
        return try #require(Bundle(path: path))
    }

    private func string(_ key: L10nKey, in bundle: Bundle, locale: Locale) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: bundle, locale: locale)
    }

    @Test func restoresStoredChoices() {
        let store = InMemorySettingsStore(strings: [
            .numberSystem: NumberSystem.latin.rawValue
        ])

        let manager = makeManager(store, language: .arabic)

        #expect(manager.language == .arabic)
        #expect(manager.numberSystem == .latin)
    }

    @Test func unrecognisedStoredValuesFallBack() {
        let store = InMemorySettingsStore(strings: [
            .numberSystem: "roman"
        ])

        let manager = makeManager(store, language: .arabic)

        #expect(manager.numberSystem == NumberSystem.preferred(for: manager.language))
    }

    /// The language is whatever the process is running in, which is the user's choice made in
    /// the Settings app. Nothing in the app writes it, and there is no key it could be written
    /// to — `SettingsKey` has no `language` case, so a regression here would not compile.
    @Test func theLanguageComesFromTheBundleTheAppLaunchedWith() {
        // The test host is the app, so this is the real reading, whatever the machine is set to.
        #expect(AppLanguage.allCases.contains(AppLanguage.current()))
        #expect(makeManager(language: .arabic).language == .arabic)
        #expect(makeManager(language: .english).language == .english)
    }

    /// Digits still default from the language when the user has never chosen — the one place the
    /// system's language still seeds an app-owned preference.
    @Test func digitsDefaultFromTheProcessLanguage() {
        #expect(makeManager(language: .arabic).numberSystem == .arabicIndic)
        #expect(makeManager(language: .english).numberSystem == .latin)
    }

    @Test func selectingANumberSystemPersistsIt() {
        let store = InMemorySettingsStore()
        let manager = makeManager(store)

        manager.select(numberSystem: .arabicIndic)

        #expect(store.string(for: .numberSystem) == NumberSystem.arabicIndic.rawValue)
        #expect(makeManager(store).numberSystem == .arabicIndic)
    }

    /// The clock choice has no `preferred(for:)` sibling on purpose: unset means "keep following
    /// the device", which is not the same as resolving to whichever form the region uses today.
    @Test func theClockFormatDefaultsToFollowingTheSystem() {
        #expect(makeManager().clockFormat == .system)
    }

    @Test func selectingAClockFormatPersistsIt() {
        let store = InMemorySettingsStore()
        let manager = makeManager(store)

        manager.select(clockFormat: .twentyFourHour)

        #expect(store.string(for: .clockFormat) == ClockFormat.twentyFourHour.rawValue)
        #expect(makeManager(store).clockFormat == .twentyFourHour)
    }

    /// The manager is what every screen calls, so the choice has to survive the trip through it —
    /// not just be stored.
    @Test func timeStringsFollowTheSelectedClockFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let lateAfternoon = calendar.date(bySettingHour: 17, minute: 5, second: 0, of: Date())!

        let manager = makeManager()
        manager.select(numberSystem: .latin)

        manager.select(clockFormat: .twentyFourHour)
        #expect(manager.timeString(lateAfternoon).contains("17"))

        manager.select(clockFormat: .twelveHour)
        #expect(!manager.timeString(lateAfternoon).contains("17"))
    }

    /// Direction is a property of the language, and the system applies it to the whole app when
    /// it launches — nothing here overrides `\.layoutDirection` any more, which is what stopped
    /// `Form` and `List` rendering their contents mirrored.
    @Test func arabicIsTheRightToLeftLanguage() {
        #expect(AppLanguage.arabic.isRightToLeft)
        #expect(!AppLanguage.english.isRightToLeft)
    }

    @Test func numbersFollowTheSelectedSystem() {
        let manager = makeManager()

        manager.select(numberSystem: .arabicIndic)
        #expect(manager.string(7) == "٧")

        manager.select(numberSystem: .latin)
        #expect(manager.string(7) == "7")
    }

    /// End-to-end check that the built bundle really carries both languages.
    ///
    /// It is also what makes routing the user to the Settings app viable at all: iOS only offers
    /// an app its own Language row when the bundle ships more than one localization. If
    /// `ar.lproj` ever stopped being built, the row would quietly disappear and the app would
    /// have no way to change language at all — so this failing is the early warning for that.
    @Test func bothLanguagesShipInTheBuiltBundle() throws {
        let english = try catalog(for: .english)
        #expect(string(.appName, in: english, locale: AppLanguage.english.locale) == "Noor")
        #expect(string(.settingsTitle, in: english, locale: AppLanguage.english.locale) == "Settings")

        let arabic = try catalog(for: .arabic)
        #expect(string(.appName, in: arabic, locale: AppLanguage.arabic.locale) == "نور")
        #expect(string(.settingsTitle, in: arabic, locale: AppLanguage.arabic.locale) == "الإعدادات")
    }

    @Test(arguments: AppLanguage.allCases)
    func everyKeyHasATranslationIn(_ language: AppLanguage) throws {
        let bundle = try catalog(for: language)

        for key in L10nKey.allCases {
            // A missing key resolves to the key itself.
            #expect(
                string(key, in: bundle, locale: language.locale) != key.rawValue,
                "\(key.rawValue) is missing in \(language.rawValue)"
            )
        }
    }

    /// The manager reads from the main bundle now, so it can only speak the process's language —
    /// which is the correct behaviour, and worth pinning so nobody reintroduces a lookup.
    @Test func theManagerResolvesInTheProcessLanguage() {
        let manager = makeManager()

        #expect(manager.string(.appName) == "Noor" || manager.string(.appName) == "نور")
        #expect(manager.string(.settingsTitle) != L10nKey.settingsTitle.rawValue)
    }
}
