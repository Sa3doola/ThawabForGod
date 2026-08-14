//
//  L10nKey.swift
//  ThawabForGod
//

import Foundation

/// Every user-facing string in the app, as a typed key.
///
/// Raw values are the keys in `Localizable.xcstrings`. Features never pass raw strings
/// around, and a missing key is a compile error rather than a wrong-looking screen.
nonisolated enum L10nKey: String, CaseIterable, Sendable {
    case appName = "app_name"

    case settingsTitle = "settings_title"

    case languageLabel = "language_label"
    case languageArabic = "language_arabic"
    case languageEnglish = "language_english"

    case appearanceLabel = "appearance_label"
    case appearanceSystem = "appearance_system"
    case appearanceLight = "appearance_light"
    case appearanceDark = "appearance_dark"

    case accentLabel = "accent_label"
    case accentAmber = "accent_amber"
    case accentEmerald = "accent_emerald"
    case accentSapphire = "accent_sapphire"
    case accentRose = "accent_rose"

    case numbersLabel = "numbers_label"
    case numbersArabicIndic = "numbers_arabic_indic"
    case numbersLatin = "numbers_latin"

    case paletteTitle = "palette_title"
    case typeScaleTitle = "type_scale_title"
    case sampleGreeting = "sample_greeting"
    case sampleCount = "sample_count"
}
