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

    // The Quran reader's own look, all read and written by `QuranReaderSettings`. Unset means the
    // default — the reader has to have moved something for any of these to exist. One key per
    // choice rather than Mushaf's single `readerState` blob, so a reset or a new default touches
    // only what the reader never chose (D4).
    //
    // Three keep the names Noor's own reader gave them: the separated mode's text size, its face
    // (a `ReaderFont` raw value) and keeping the screen awake.
    case readerTextSize
    case readerKeepsScreenAwake
    case readerFont
    // The rest arrived with the Mushaf port. Enums are stored as raw values.
    /// `QuranDisplayMode`. Unset: the printed page where the build has it, separated otherwise.
    case quranDisplayMode
    /// `ReaderTheme`. Unset: Paper.
    case quranReaderTheme
    /// Use the dark page while the system is dark. Unset: on.
    case quranFollowsSystemAppearance
    /// Juz, hizb, quarter and sajdah labels in a Mushaf page's margin. Unset: on.
    case quranShowsMarginMarkers
    /// Separated mode: the enabled translations under each ayah. Unset: on.
    case quranShowsTranslationInSeparated
    /// `PhoneLandscapeLayout`. Unset: one page.
    case quranPhoneLandscape
    /// `FlatOpenLayout`. Unset: a spread.
    case quranFlatOpen
    /// The enabled translations, in order: a JSON `[String]` of pack ids. Unset (or unreadable):
    /// every installed one. An empty list is a real choice — all off.
    case quranEnabledTranslations
    /// The enabled tafsirs, in order: a JSON `[String]` of pack ids. Unset: every installed one.
    case quranEnabledTafsirs
    /// The tafsir the panel opens on. Unset: automatic.
    case quranDefaultTafsir
    /// The last searches the reader submitted, newest first: a JSON `[String]` of what they typed.
    /// Unset: none.
    case quranRecentSearches

    /// How large the adhkar are set. **Its own key rather than `readerTextSize`**, deliberately:
    /// the Quran is read in long sittings on a page the reader chose a paper for, and a dhikr is
    /// one short passage said several times over — the size that suits one is not the size that
    /// suits the other, and a single key would have each screen silently overwrite the other's
    /// answer. Unset until the reader moves the control.
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
