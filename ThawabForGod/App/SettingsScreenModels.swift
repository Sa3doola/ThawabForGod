//
//  SettingsScreenModels.swift
//  ThawabForGod
//

import Foundation

/// The seven view models Settings routes to, in one value.
///
/// It lives at the composition root rather than in the feature because *assembling* them is the
/// root's job — `SettingsView` names only the protocol it reads. A struct rather than seven
/// parameters threaded through the view: the root list does not care what any of them are, only
/// that it can hand one to the screen a row opens.
@MainActor
struct SettingsScreenModels: SettingsScreens {
    let homeCustomization: HomeCustomizationViewModel
    let appearance: AppearanceSettingsViewModel
    let languageAndFormat: LanguageFormatSettingsViewModel
    let prayerCalculation: PrayerCalculationSettingsViewModel
    let reminders: RemindersSettingsViewModel
    let tips: TipsSettingsViewModel
    let about: AboutViewModel

    /// macOS only, matching `SettingsScreens`. There is no screen behind it on iOS and
    /// `SettingsRoute.macIntegration` never reaches the root there.
    #if os(macOS)
    let macIntegration: MacSettingsViewModel
    #endif
}
