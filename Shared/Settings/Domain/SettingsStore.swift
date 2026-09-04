//
//  SettingsStore.swift
//  ThawabForGod
//

import Foundation

/// Every user preference the app persists. One list so no layer invents its own key.
nonisolated enum SettingsKey: String, CaseIterable, Sendable {
    case accentPalette
    case appearance
    // No `language`: it is the system's, chosen in the app's own page in the Settings app. A key
    // here would outrank that choice forever, which is the exact failure the note above
    // describes — and it is why an in-app switcher was removed rather than repaired.
    case numberSystem
    case clockFormat

    // Seeded by onboarding, read from then on by prayer times, Settings and the reminders.
    case onboardingCompleted
    case calculationMethod
    case asrMadhab
    case latitude
    case longitude

    // Where the app last actually was, as opposed to where onboarding was told it would be.
    // A *cache*, not a preference — the only two keys here that the user never chose — which is
    // why they are separate from the pair above rather than overwriting it. See
    // `SettingsStore+PrayerTimes` for the rule, and `CoreLocationService` for the one writer.
    case lastKnownLatitude
    case lastKnownLongitude

    // How Home is arranged: which sections, in what order, and which shortcut circles. One key
    // holding the whole value as JSON — see `HomeLayoutRepository` for why it is not nine.
    case homeLayout

    // The reading screen's own look. Unset means the app's colours at the app's size — the
    // reader has to have opened the panel and moved something for any of these to exist, which
    // is what lets "reset" write `nil` back rather than the defaults.
    case readerPaper
    case readerTextSize
    case readerLineSpacing
    case readerShowsVerseNumbers
    case readerKeepsScreenAwake

    /// How large the adhkar are set. **Its own key rather than `readerTextSize`**, deliberately:
    /// the Quran is read in long sittings on a page the reader chose a paper for, and a dhikr is
    /// one short passage said several times over — the size that suits one is not the size that
    /// suits the other, and a single key would have each screen silently overwrite the other's
    /// answer. Unset until the reader moves the control. Sharing the Quran's whole
    /// `ReaderSettings` across both tabs is a slice of its own; this is the one value the adhkar
    /// screen actually needs.
    case adhkarTextSize

    // One per obligatory prayer. Unset means on — a reminder the user has never opinionated
    // about should arrive, and writing `true` at first launch would breach the rule above.
    case reminderFajr
    case reminderDhuhr
    case reminderAsr
    case reminderMaghrib
    case reminderIsha

    // The Mac's menu bar. Both unset by default, and asymmetrically so on purpose: the status
    // item is on unless the user turns it off, because it is the whole reason a Mac build of a
    // prayer-times app is worth having — while hiding the Dock icon is a choice nobody should
    // arrive at by accident. macOS only; the iOS build never reads either.
    case menuBarEnabled
    case menuBarOnly
    // How much of the status item to draw — a `MenuBarStatusStyle` raw value. Unset means
    // `automatic`, which lets the width decide; the other cases pin a rung, for somebody whose
    // menu bar is permanently crowded and who would rather choose once than watch the item grow
    // back every time an app quits.
    case menuBarStatusStyle
}

/// Small key/value store for user preferences.
///
/// `nonisolated` is explicit: the module default is `MainActor`, but persistence and
/// networking read settings off the main actor.
nonisolated protocol SettingsStore: Sendable {
    func string(for key: SettingsKey) -> String?
    func set(_ value: String?, for key: SettingsKey)

    func bool(for key: SettingsKey) -> Bool?
    func set(_ value: Bool?, for key: SettingsKey)

    func double(for key: SettingsKey) -> Double?
    func set(_ value: Double?, for key: SettingsKey)
}
