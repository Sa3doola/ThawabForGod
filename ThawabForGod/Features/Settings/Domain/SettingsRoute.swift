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

    /// The Islamic calendar's own preferences: Gregorian dates, week start, dots, Hijri offset.
    case calendar

    /// The Quran reader's preferences: mode, theme, fonts, packs.
    case quran
    case tips

    /// The menu bar, the Dock icon and launch at login. macOS only — see `isAvailable`.
    case macIntegration

    case about

    /// Reached from `about` rather than from the root — it is what the app is built from, which
    /// is a fact *about* the app rather than a subject of its own.
    case sources

    /// Reached from `quran`: which translations and tafsirs are on, and in what order.
    case quranPacks

    /// The rows the root shows. `sources` and `quranPacks` are not among them: they are one level
    /// further in.
    static let root: [SettingsRoute] = allCases.filter {
        $0 != .sources && $0 != .quranPacks && $0.isAvailable
    }

    /// Whether this build has the screen at all.
    ///
    /// The same forward-and-sideways-compatibility contract `HomeSectionKind` and `HomeShortcut`
    /// hold, applied to a platform rather than to a feature that has not shipped: the case exists
    /// in both builds so nothing has to be `#if`-ed except the answer, and a route that is not
    /// available is filtered out of the root and never pushed.
    var isAvailable: Bool {
        switch self {
        case .macIntegration:
            #if os(macOS)
            true
            #else
            false
            #endif

        case .homeCustomization, .appearance, .languageAndFormat, .prayerCalculation,
             .reminders, .calendar, .quran, .tips, .about, .sources, .quranPacks:
            true
        }
    }

    var titleKey: L10nKey {
        switch self {
        case .homeCustomization: .homeCustomizeTitle
        case .appearance: .settingsAppearanceSection
        case .languageAndFormat: .settingsFormatSection
        case .prayerCalculation: .settingsCalculationSection
        case .reminders: .settingsRemindersSection
        case .calendar: .calendarTitle
        case .quran: .settingsQuranSection
        case .tips: .settingsTipsSection
        case .macIntegration: .settingsMacSection
        case .about: .settingsAboutSection
        case .sources: .settingsSourcesTitle
        case .quranPacks: .quranPacksTitle
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
        case .calendar: "calendar"
        case .quran: "book"
        case .quranPacks: "books.vertical"
        case .tips: "lightbulb"
        case .macIntegration: "menubar.rectangle"
        case .about: "info.circle"
        case .sources: "book.closed"
        }
    }
}
