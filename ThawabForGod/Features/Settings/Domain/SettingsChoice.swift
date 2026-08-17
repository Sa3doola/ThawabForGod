//
//  SettingsChoice.swift
//  ThawabForGod
//

import Foundation

/// A preference the user picks from a fixed set of cases.
///
/// Every choice on the Settings screen already had this shape — a `String`-backed enum, all cases
/// offered, each carrying its own `L10nKey` — so naming the shape lets one picker row serve all
/// seven instead of seven near-identical bodies. The conformances below are the whole
/// implementation: not one of them adds a member.
nonisolated protocol SettingsChoice: CaseIterable, Identifiable, Hashable, Sendable {
    var labelKey: L10nKey { get }
}

// Marked `nonisolated` because the module's default isolation is `MainActor`, and a conformance
// pinned to the main actor could not be used from the pure-Swift contexts these enums live in.
//
// `AppLanguage` is deliberately absent: it has the right shape, but there is no picker for it.
// The language is the system's, chosen in the Settings app — see `FormatSettingsSection`.

nonisolated extension AccentPalette: SettingsChoice {}
nonisolated extension AppearanceOverride: SettingsChoice {}
nonisolated extension NumberSystem: SettingsChoice {}
nonisolated extension ClockFormat: SettingsChoice {}
nonisolated extension PrayerCalculationMethod: SettingsChoice {}
nonisolated extension AsrMadhab: SettingsChoice {}
