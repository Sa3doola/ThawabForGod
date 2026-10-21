//
//  QuranReaderSettings.swift
//  ThawabForGod
//

import Observation
import SwiftUI

/// The Quran reader's preferences: how a page looks and how the reader is laid out.
///
/// Mushaf's `ReaderSettings` with its storage replaced (QURAN_MIGRATION_PLAN.md, D4). There it
/// was one Codable value written whole into `UserDefaults`; here each choice is its own
/// `SettingsKey`, written through `SettingsStore` when — and only when — the reader makes it. A
/// whole-value save would write every default alongside the one thing that changed, and a stored
/// default outranks any better default a later build ships, forever (CLAUDE.md, "only write a key
/// the user actually chose"). So reading falls back to a default in code, and `reset()` deletes
/// keys rather than writing defaults into them.
///
/// Shaped like the app's other managers (`ThemeManager`, `LocalizationManager`): `@Observable`,
/// main-actor isolated because it exists to drive SwiftUI, owned by `AppContainer` so the reader
/// and its settings sheet read one instance.
///
/// **What is not here, on purpose.** The digits on a page, its juz and hizb are the app's
/// `NumberSystem` (`LocalizationManager`) — Mushaf's own numeral setting is dropped. The Mushaf
/// style is not a choice while there is one. The translation and tafsir lists arrive with the
/// screens that edit them (M5).
@Observable
@MainActor
final class QuranReaderSettings {

    // MARK: Ranges

    /// Separated mode's text size, in points before Dynamic Type. Mushaf's range and default: wider
    /// than the app's type scale because Arabic marks above and below the line are what a reader
    /// with good eyesight may still want enlarged.
    static let textSizeRange: ClosedRange<Double> = 18...48
    static let textSizeStep: Double = 2
    static let defaultTextSize: Double = 28

    // MARK: State

    /// What the bundled Quran database can draw. Gates the Mushaf mode: a build without the
    /// printed layout (the public Tanzil one) never offers it, whatever was stored.
    private(set) var capabilities: QuranCapabilities

    /// The mode the reader picked, or `nil` if they never picked one.
    private var chosenDisplayMode: QuranDisplayMode?
    private(set) var theme: ReaderTheme
    private(set) var followsSystemAppearance: Bool
    private(set) var textSize: Double
    private(set) var font: ReaderFont
    private(set) var keepsScreenAwake: Bool
    private(set) var showsMarginMarkers: Bool
    private(set) var showsTranslationInSeparated: Bool
    private(set) var phoneLandscape: PhoneLandscapeLayout
    private(set) var flatOpen: FlatOpenLayout
    private(set) var pageTurn: MushafPageTurnStyle
    /// The translations the reader switched on, in order. `nil`: never chosen, so every installed
    /// pack. `[]` is a choice (all off).
    private(set) var enabledTranslations: [ContentPackID]?
    private(set) var enabledTafsirs: [ContentPackID]?
    /// The tafsir the panel opens on; `nil` is Automatic.
    private(set) var defaultTafsir: ContentPackID?

    @ObservationIgnored private let settingsStore: any SettingsStore

    /// - Parameter capabilities: what the bundled database carries. `.text` (every build) until the
    ///   container has asked the database; `apply(_:)` updates it.
    init(settingsStore: any SettingsStore, capabilities: QuranCapabilities = .text) {
        self.settingsStore = settingsStore
        self.capabilities = capabilities
        // Every read falls back rather than trapping: an unset key, a value that names a case this
        // build no longer has, or a hand-edited number.
        chosenDisplayMode = settingsStore.string(for: .quranDisplayMode).flatMap(QuranDisplayMode.init(rawValue:))
        theme = settingsStore.string(for: .quranReaderTheme).flatMap(ReaderTheme.init(rawValue:)) ?? .fallback
        followsSystemAppearance = settingsStore.bool(for: .quranFollowsSystemAppearance) ?? true
        textSize = Self.clampedTextSize(settingsStore.double(for: .readerTextSize) ?? Self.defaultTextSize)
        font = settingsStore.string(for: .readerFont).flatMap(ReaderFont.init(rawValue:)) ?? .fallback
        keepsScreenAwake = settingsStore.bool(for: .readerKeepsScreenAwake) ?? false
        showsMarginMarkers = settingsStore.bool(for: .quranShowsMarginMarkers) ?? true
        showsTranslationInSeparated = settingsStore.bool(for: .quranShowsTranslationInSeparated) ?? true
        phoneLandscape = settingsStore.string(for: .quranPhoneLandscape).flatMap(PhoneLandscapeLayout.init(rawValue:)) ?? .fallback
        flatOpen = settingsStore.string(for: .quranFlatOpen).flatMap(FlatOpenLayout.init(rawValue:)) ?? .fallback
        pageTurn = settingsStore.string(for: .quranPageTurn).flatMap(MushafPageTurnStyle.init(rawValue:)) ?? .fallback
        enabledTranslations = Self.decodeIDs(settingsStore.string(for: .quranEnabledTranslations))
        enabledTafsirs = Self.decodeIDs(settingsStore.string(for: .quranEnabledTafsirs))
        defaultTafsir = settingsStore.string(for: .quranDefaultTafsir).map { ContentPackID(rawValue: $0) }
    }

    /// Records what the database turned out to carry. Writes nothing: a stored Mushaf choice in a
    /// build that cannot draw it is kept, and comes back if the full data does.
    func apply(_ capabilities: QuranCapabilities) {
        self.capabilities = capabilities
    }

    // MARK: Resolved values

    /// The modes this build can show, in the order the settings sheet lists them.
    var availableDisplayModes: [QuranDisplayMode] {
        capabilities.supportsMushafPages ? [.mushaf, .separated] : [.separated]
    }

    /// The mode the reader sees: their choice if this build can show it, else the printed page
    /// where there is one (Mushaf's default), else separated.
    var displayMode: QuranDisplayMode {
        if let chosenDisplayMode, availableDisplayModes.contains(chosenDisplayMode) {
            return chosenDisplayMode
        }
        return availableDisplayModes[0]
    }

    /// The theme a page is drawn with right now: Dark while the system is dark, if the reader
    /// asked to follow it.
    func resolvedTheme(systemColorScheme: ColorScheme) -> ReaderTheme {
        theme.resolved(followingSystem: followsSystemAppearance, systemIsDark: systemColorScheme == .dark)
    }

    var canEnlargeText: Bool { textSize < Self.textSizeRange.upperBound }
    var canShrinkText: Bool { textSize > Self.textSizeRange.lowerBound }

    // MARK: Choices — each writes its own key and nothing else

    /// Ignored for a mode this build cannot show, so the sheet can never store a choice the
    /// reader was not offered.
    func select(displayMode: QuranDisplayMode) {
        guard availableDisplayModes.contains(displayMode) else { return }
        chosenDisplayMode = displayMode
        settingsStore.set(displayMode.rawValue, for: .quranDisplayMode)
    }

    func select(theme: ReaderTheme) {
        self.theme = theme
        settingsStore.set(theme.rawValue, for: .quranReaderTheme)
    }

    func setFollowsSystemAppearance(_ isOn: Bool) {
        followsSystemAppearance = isOn
        settingsStore.set(isOn, for: .quranFollowsSystemAppearance)
    }

    func setTextSize(_ size: Double) {
        let clamped = Self.clampedTextSize(size)
        textSize = clamped
        settingsStore.set(clamped, for: .readerTextSize)
    }

    func enlargeText() { setTextSize(textSize + Self.textSizeStep) }
    func shrinkText() { setTextSize(textSize - Self.textSizeStep) }

    func select(font: ReaderFont) {
        self.font = font
        settingsStore.set(font.rawValue, for: .readerFont)
    }

    func setKeepsScreenAwake(_ isOn: Bool) {
        keepsScreenAwake = isOn
        settingsStore.set(isOn, for: .readerKeepsScreenAwake)
    }

    func setShowsMarginMarkers(_ isOn: Bool) {
        showsMarginMarkers = isOn
        settingsStore.set(isOn, for: .quranShowsMarginMarkers)
    }

    func setShowsTranslationInSeparated(_ isOn: Bool) {
        showsTranslationInSeparated = isOn
        settingsStore.set(isOn, for: .quranShowsTranslationInSeparated)
    }

    func select(phoneLandscape: PhoneLandscapeLayout) {
        self.phoneLandscape = phoneLandscape
        settingsStore.set(phoneLandscape.rawValue, for: .quranPhoneLandscape)
    }

    func select(flatOpen: FlatOpenLayout) {
        self.flatOpen = flatOpen
        settingsStore.set(flatOpen.rawValue, for: .quranFlatOpen)
    }

    func select(pageTurn: MushafPageTurnStyle) {
        self.pageTurn = pageTurn
        settingsStore.set(pageTurn.rawValue, for: .quranPageTurn)
    }

    func setEnabledTranslations(_ ids: [ContentPackID]) {
        enabledTranslations = ids
        settingsStore.set(Self.encodeIDs(ids), for: .quranEnabledTranslations)
    }

    func setEnabledTafsirs(_ ids: [ContentPackID]) {
        enabledTafsirs = ids
        settingsStore.set(Self.encodeIDs(ids), for: .quranEnabledTafsirs)
    }

    /// `nil` is Automatic and removes the key.
    func setDefaultTafsir(_ id: ContentPackID?) {
        defaultTafsir = id
        settingsStore.set(id?.rawValue, for: .quranDefaultTafsir)
    }

    /// Back to "no preference": every key this type owns is removed, not overwritten with today's
    /// default, so the reader follows whatever default the build they run next has.
    func reset() {
        // Through each key's own type: a store is free to keep strings, bools and numbers apart
        // (`InMemorySettingsStore` does), so clearing a bool key as a string would leave it set.
        for key in Self.stringKeys { settingsStore.set(nil as String?, for: key) }
        for key in Self.boolKeys { settingsStore.set(nil as Bool?, for: key) }
        for key in Self.doubleKeys { settingsStore.set(nil as Double?, for: key) }
        chosenDisplayMode = nil
        theme = .fallback
        followsSystemAppearance = true
        textSize = Self.defaultTextSize
        font = .fallback
        keepsScreenAwake = false
        showsMarginMarkers = true
        showsTranslationInSeparated = true
        phoneLandscape = .fallback
        flatOpen = .fallback
        pageTurn = .fallback
        enabledTranslations = nil
        enabledTafsirs = nil
        defaultTafsir = nil
    }

    /// The keys this type reads and writes, by the type each is stored as: the lists `reset()`
    /// clears, and the ones the tests check against a store that started empty.
    static let stringKeys: [SettingsKey] = [
        .quranDisplayMode, .quranReaderTheme, .readerFont, .quranPhoneLandscape, .quranFlatOpen,
        .quranPageTurn, .quranEnabledTranslations, .quranEnabledTafsirs, .quranDefaultTafsir,
    ]
    static let boolKeys: [SettingsKey] = [
        .quranFollowsSystemAppearance, .readerKeepsScreenAwake, .quranShowsMarginMarkers, .quranShowsTranslationInSeparated,
    ]
    static let doubleKeys: [SettingsKey] = [.readerTextSize]

    /// A JSON `[String]`; a missing or corrupt value is `nil` ("all installed"), never `[]`.
    private static func decodeIDs(_ json: String?) -> [ContentPackID]? {
        guard let data = json?.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        return ids.map { ContentPackID(rawValue: $0) }
    }

    private static func encodeIDs(_ ids: [ContentPackID]) -> String? {
        (try? JSONEncoder().encode(ids.map(\.rawValue))).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Non-finite falls to the default rather than either bound: a stored value that is not a
    /// number is corruption, not a choice.
    private static func clampedTextSize(_ size: Double) -> Double {
        guard size.isFinite else { return defaultTextSize }
        return min(max(size, textSizeRange.lowerBound), textSizeRange.upperBound)
    }
}
