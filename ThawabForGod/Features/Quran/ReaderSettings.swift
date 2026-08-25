//
//  ReaderSettings.swift
//  ThawabForGod
//

import Observation

/// How the reader has asked for the text to look, live.
///
/// The sibling of `ThemeManager` and `CalculationSettings`, and here for the same reason both of
/// those exist: two screens act on the choice at once. The panel edits it and the page behind the
/// panel redraws from it, which a value read once and handed over as a constant cannot do.
///
/// It lives beside the Quran's view model rather than in `Core/Theming` because these are the
/// *reader's* preferences — the paper and the type metrics they are made of belong to the design
/// system, but wanting them is a thing only this feature does. Nothing outside `Features/Quran`
/// constructs one.
///
/// **It writes only what the reader chose.** Nothing is seeded at first launch and `reset()` puts
/// the keys back to unset rather than storing the defaults, so "I have never opinionated about
/// this" stays distinguishable from "I chose what the default happens to be" — the rule the
/// project's settings notes are built on, and the reason a later change to `ReaderTypography`'s
/// defaults will reach a reader who never touched the panel.
@Observable
@MainActor
final class ReaderSettings {
    private(set) var paper: ReaderPaper
    private(set) var typography: ReaderTypography

    /// Whether the ayah marker is drawn beside each verse.
    ///
    /// On unless turned off. A verse without its number is a verse nobody can cite, and citing is
    /// most of what a reader does with one — but a reader working through a page they already
    /// know wants the mushaf's flow rather than a column of markers, and that is a real way to
    /// read. Nothing is written until the switch is moved; see the note above.
    private(set) var showsVerseNumbers: Bool

    /// Whether the screen is kept from dimming while the reader is on a page.
    ///
    /// Off unless asked for, and that asymmetry is deliberate: an app that quietly stopped a
    /// phone sleeping would be draining a battery nobody consented to. A reader following a page
    /// aloud, with the phone on a stand and their hands not on it, is the one who wants it — and
    /// they are able to ask.
    private(set) var keepsScreenAwake: Bool

    @ObservationIgnored private let settingsStore: any SettingsStore

    init(settingsStore: any SettingsStore) {
        self.settingsStore = settingsStore
        self.paper = Self.storedPaper(in: settingsStore)
        self.typography = Self.storedTypography(in: settingsStore)
        self.showsVerseNumbers = settingsStore.bool(for: .readerShowsVerseNumbers) ?? true
        self.keepsScreenAwake = settingsStore.bool(for: .readerKeepsScreenAwake) ?? false
    }

    /// The style the reading screen draws with, resolved against the app's current theme.
    ///
    /// Here rather than in the view because the `.system` paper has to be resolved against a
    /// `Theme` that this type has no business holding — the view has one in its environment, so
    /// it passes it in and gets a finished value back.
    func style(on theme: Theme) -> ReadingStyle {
        ReadingStyle(palette: theme.reading(paper), typography: typography)
    }

    func select(paper: ReaderPaper) {
        self.paper = paper
        settingsStore.set(paper.rawValue, for: .readerPaper)
    }

    /// Stores what was asked for and keeps what was allowed: `ReaderTypography` clamps, so a
    /// value out of range is persisted as the value the reader will actually see.
    func select(textSize: Double) {
        typography = typography.with(textSize: textSize)
        settingsStore.set(typography.textSize, for: .readerTextSize)
    }

    func select(lineSpacing: Double) {
        typography = typography.with(lineSpacing: lineSpacing)
        settingsStore.set(typography.lineSpacing, for: .readerLineSpacing)
    }

    func select(showsVerseNumbers: Bool) {
        self.showsVerseNumbers = showsVerseNumbers
        settingsStore.set(showsVerseNumbers, for: .readerShowsVerseNumbers)
    }

    func select(keepsScreenAwake: Bool) {
        self.keepsScreenAwake = keepsScreenAwake
        settingsStore.set(keepsScreenAwake, for: .readerKeepsScreenAwake)
    }

    /// Back to no preference at all — see the note above on why that is not the same as storing
    /// the defaults.
    func reset() {
        settingsStore.set(nil as String?, for: .readerPaper)
        settingsStore.set(nil as Double?, for: .readerTextSize)
        settingsStore.set(nil as Double?, for: .readerLineSpacing)
        settingsStore.set(nil as Bool?, for: .readerShowsVerseNumbers)
        settingsStore.set(nil as Bool?, for: .readerKeepsScreenAwake)

        paper = Self.storedPaper(in: settingsStore)
        typography = Self.storedTypography(in: settingsStore)
        showsVerseNumbers = true
        keepsScreenAwake = false
    }

    /// Whether anything here has been chosen — what the reset control is enabled by.
    var hasChoices: Bool {
        paper != .fallback || typography != .fallback || !showsVerseNumbers || keepsScreenAwake
    }

    // MARK: Reading the store

    private static func storedPaper(in store: any SettingsStore) -> ReaderPaper {
        // An unset or unrecognised value falls back rather than trapping, as `ThemeManager` does.
        store.string(for: .readerPaper).flatMap(ReaderPaper.init(rawValue:)) ?? .fallback
    }

    private static func storedTypography(in store: any SettingsStore) -> ReaderTypography {
        ReaderTypography(
            textSize: store.double(for: .readerTextSize) ?? ReaderTypography.fallback.textSize,
            lineSpacing: store.double(for: .readerLineSpacing)
                ?? ReaderTypography.fallback.lineSpacing
        )
    }
}
