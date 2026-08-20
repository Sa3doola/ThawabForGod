//
//  SettingsRoute.swift
//  ThawabForGod
//

import Foundation

/// The screens Settings can push.
///
/// Settings stopped being one long form when it grew past four groups: a list that has to be
/// scrolled to find the thing you came for is a list that has outgrown being a list. So the root
/// is now seven rows, each opening a screen about one subject, and this enum is what they open.
///
/// Declaration order is the order the root lists them, which is roughly how often they are wanted
/// — how the app *looks* first, how it *reads* second, and what it is made of last.
nonisolated enum SettingsRoute: String, CaseIterable, Hashable, Sendable {
    case homeCustomization
    case appearance
    case languageAndFormat
    case prayerCalculation
    case reminders
    case tips
    case about

    /// Reached from `about` rather than from the root — it is what the app is built from, which
    /// is a fact *about* the app rather than a subject of its own.
    case sources

    /// The rows the root shows. `sources` is not among them: it is one level further in.
    static let root: [SettingsRoute] = allCases.filter { $0 != .sources }

    var titleKey: L10nKey {
        switch self {
        case .homeCustomization: .homeCustomizeTitle
        case .appearance: .settingsAppearanceSection
        case .languageAndFormat: .settingsFormatSection
        case .prayerCalculation: .settingsCalculationSection
        case .reminders: .settingsRemindersSection
        case .tips: .settingsTipsSection
        case .about: .settingsAboutSection
        case .sources: .settingsSourcesTitle
        }
    }

    /// The symbol in the tinted square beside the row.
    var symbol: String {
        switch self {
        case .homeCustomization: "square.grid.2x2"
        case .appearance: "paintpalette"
        case .languageAndFormat: "textformat"
        case .prayerCalculation: "sun.and.horizon"
        case .reminders: "bell"
        case .tips: "lightbulb"
        case .about: "info.circle"
        case .sources: "book.closed"
        }
    }
}
