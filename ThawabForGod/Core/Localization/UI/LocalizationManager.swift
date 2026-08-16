//
//  LocalizationManager.swift
//  ThawabForGod
//

import Observation
import SwiftUI

/// Owns the language and digit choices, and resolves strings and numbers for them.
///
/// Why strings are resolved here instead of by `Text("key")`: SwiftUI looks a key up in the
/// language the *process* launched with, so a plain `Text("key")` would not change until the
/// app is restarted. Going through this object solves both halves — it reads the string from
/// the language's own `.lproj` bundle, and because the lookup touches observable state, every
/// view that displays a string re-renders the moment the language changes.
///
/// The corollary: never wrap this in a static or global accessor. That would drop the
/// observation dependency and the UI would silently keep the old language.
@Observable
@MainActor
final class LocalizationManager {
    private(set) var language: AppLanguage
    private(set) var numberSystem: NumberSystem

    @ObservationIgnored private let settingsStore: any SettingsStore
    @ObservationIgnored private let numberFormatting: any NumberFormattingService
    @ObservationIgnored private let timeFormatting: any TimeFormattingService

    init(
        settingsStore: any SettingsStore,
        numberFormatting: any NumberFormattingService,
        timeFormatting: any TimeFormattingService
    ) {
        self.settingsStore = settingsStore
        self.numberFormatting = numberFormatting
        self.timeFormatting = timeFormatting

        let language = settingsStore.string(for: .language)
            .flatMap(AppLanguage.init(rawValue:)) ?? .preferred
        self.language = language
        self.numberSystem = settingsStore.string(for: .numberSystem)
            .flatMap(NumberSystem.init(rawValue:)) ?? .preferred(for: language)
    }

    // MARK: Choices

    func select(language: AppLanguage) {
        self.language = language
        settingsStore.set(language.rawValue, for: .language)
    }

    func select(numberSystem: NumberSystem) {
        self.numberSystem = numberSystem
        settingsStore.set(numberSystem.rawValue, for: .numberSystem)
    }

    // MARK: Resolved values

    var locale: Locale { language.locale }

    var layoutDirection: LayoutDirection { language.isRightToLeft ? .rightToLeft : .leftToRight }

    /// The string catalog for the selected language, falling back to the main bundle.
    private var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    func string(_ key: L10nKey) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: bundle, locale: locale)
    }

    /// - Parameter grouped: pass `false` for a number that names rather than counts — a year,
    ///   a page, an ayah — where a thousands separator would be wrong in every locale.
    func string(_ value: Int, grouped: Bool = true) -> String {
        numberFormatting.string(from: value, grouped: grouped, system: numberSystem)
    }

    func string(_ value: Double, fractionDigits: Int = 1) -> String {
        numberFormatting.string(from: value, fractionDigits: fractionDigits, system: numberSystem)
    }

    /// A clock time in the user's language and digits. Prefer this over `Text(date, style:)`,
    /// which can only follow the locale and so cannot honour a digit choice made separately
    /// from the language.
    func timeString(_ date: Date) -> String {
        timeFormatting.timeString(from: date, language: language, system: numberSystem)
    }

    /// A remaining duration as `h:mm:ss`.
    func countdownString(_ interval: TimeInterval) -> String {
        timeFormatting.countdownString(from: interval, system: numberSystem)
    }
}
