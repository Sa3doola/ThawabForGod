//
//  ReaderSettingsTests.swift
//  ThawabForGodTests
//

import Testing
@testable import ThawabForGod

@MainActor
struct ReaderSettingsTests {

    @Test func fallsBackToTheAppsOwnLookWhenNothingIsStored() {
        let settings = ReaderSettings(settingsStore: InMemorySettingsStore())

        #expect(settings.paper == .system)
        #expect(settings.typography == .fallback)
        #expect(settings.hasChoices == false)
    }

    @Test func restoresStoredChoices() {
        let store = InMemorySettingsStore(
            strings: [.readerPaper: ReaderPaper.night.rawValue],
            doubles: [.readerTextSize: 32, .readerLineSpacing: 6]
        )

        let settings = ReaderSettings(settingsStore: store)

        #expect(settings.paper == .night)
        #expect(settings.typography == ReaderTypography(textSize: 32, lineSpacing: 6))
        #expect(settings.hasChoices)
    }

    @Test func unrecognisedPaperFallsBack() {
        let store = InMemorySettingsStore(strings: [.readerPaper: "vellum"])

        #expect(ReaderSettings(settingsStore: store).paper == .system)
    }

    /// A size stored outside the range reaches the reader as the size they will actually see,
    /// not as the number in the store.
    @Test func outOfRangeStoredSizeIsClampedOnTheWayIn() {
        let store = InMemorySettingsStore(doubles: [.readerTextSize: 500])

        let settings = ReaderSettings(settingsStore: store)

        #expect(settings.typography.textSize == ReaderTypography.textSizeRange.upperBound)
    }

    // MARK: Writing

    /// The project's standing rule: only a key the user actually chose is written. Picking a
    /// paper must not also stamp the two type keys with whatever the defaults happened to be.
    @Test func writesOnlyTheKeyThatWasChosen() {
        let store = InMemorySettingsStore()
        let settings = ReaderSettings(settingsStore: store)

        settings.select(paper: .parchment)

        #expect(store.string(for: .readerPaper) == ReaderPaper.parchment.rawValue)
        #expect(store.double(for: .readerTextSize) == nil)
        #expect(store.double(for: .readerLineSpacing) == nil)
    }

    @Test func persistsTheClampedSizeRatherThanWhatWasAskedFor() {
        let store = InMemorySettingsStore()
        let settings = ReaderSettings(settingsStore: store)

        settings.select(textSize: 900)

        #expect(settings.typography.textSize == ReaderTypography.textSizeRange.upperBound)
        #expect(store.double(for: .readerTextSize) == ReaderTypography.textSizeRange.upperBound)
    }

    @Test func changingTheSizeLeavesTheSpacingAlone() {
        let store = InMemorySettingsStore(doubles: [.readerLineSpacing: 4])
        let settings = ReaderSettings(settingsStore: store)

        settings.select(textSize: 26)

        #expect(settings.typography == ReaderTypography(textSize: 26, lineSpacing: 4))
    }

    // MARK: Face and medallion

    @Test func defaultsToTheMadinahFaceAndTheFirstMedallion() {
        let settings = ReaderSettings(settingsStore: InMemorySettingsStore())

        #expect(settings.font == .kfgqpcHafs)
        #expect(settings.markerStyle == .style1)
    }

    /// Chosen, stored, and read back by a fresh instance — which is what a relaunch is.
    @Test func faceAndMedallionSurviveARelaunch() {
        let store = InMemorySettingsStore()
        let settings = ReaderSettings(settingsStore: store)

        settings.select(font: .amiriQuran)
        settings.select(markerStyle: .style9)

        let relaunched = ReaderSettings(settingsStore: store)
        #expect(relaunched.font == .amiriQuran)
        #expect(relaunched.markerStyle == .style9)
        #expect(relaunched.hasChoices)
    }

    /// A face an older build shipped — or anything else the store might hold — is the default
    /// face, not a trap and not a name CoreText would quietly substitute.
    @Test(arguments: ["indoPak", "naskh", "", "KFGQPC"])
    func anUnknownFaceFallsBackToTheDefault(stored: String) {
        let store = InMemorySettingsStore(strings: [.readerFont: stored])

        #expect(ReaderSettings(settingsStore: store).font == .kfgqpcHafs)
    }

    @Test(arguments: ["0", "13", "style2", "-1"])
    func anUnknownMedallionFallsBackToTheFirst(stored: String) {
        let store = InMemorySettingsStore(strings: [.readerAyahMarkerStyle: stored])

        #expect(ReaderSettings(settingsStore: store).markerStyle == .style1)
    }

    @Test func choosingAFaceWritesOnlyThatKey() {
        let store = InMemorySettingsStore()
        let settings = ReaderSettings(settingsStore: store)

        settings.select(font: .amiriQuran)

        #expect(store.string(for: .readerFont) == ReaderFont.amiriQuran.rawValue)
        #expect(store.string(for: .readerAyahMarkerStyle) == nil)
        #expect(store.string(for: .readerPaper) == nil)
    }

    @Test func theResolvedStyleCarriesTheFaceAndMedallion() {
        let store = InMemorySettingsStore()
        let settings = ReaderSettings(settingsStore: store)
        settings.select(font: .amiriQuran)
        settings.select(markerStyle: .style4)

        let style = settings.style(on: Theme())

        #expect(style.font == .amiriQuran)
        #expect(style.markerStyle == .style4)
    }

    /// Amiri's marks stack higher and deeper than KFGQPC's, so its floor is the larger one at
    /// every size — the reason the leading is per face at all.
    @Test(arguments: Array(stride(
        from: ReaderTypography.textSizeRange.lowerBound,
        through: ReaderTypography.textSizeRange.upperBound,
        by: ReaderTypography.textSizeStep
    )))
    func amiriAlwaysGetsMoreLeadingThanKFGQPC(size: Double) {
        #expect(ReaderFont.amiriQuran.lineSpacing(for: size) > ReaderFont.kfgqpcHafs.lineSpacing(for: size))
    }

    // MARK: Reset

    /// Back to *unset*, not back to the defaults written down. A stored value outranks the
    /// default forever, so resetting by writing `20` would leave a reader who never had an
    /// opinion pinned to today's number if that number ever changes.
    @Test func resetClearsTheKeysRatherThanStoringTheDefaults() {
        let store = InMemorySettingsStore()
        let settings = ReaderSettings(settingsStore: store)

        settings.select(paper: .night)
        settings.select(textSize: 34)
        settings.select(lineSpacing: 2)
        settings.select(font: .amiriQuran)
        settings.select(markerStyle: .style12)
        settings.reset()

        #expect(store.string(for: .readerPaper) == nil)
        #expect(store.double(for: .readerTextSize) == nil)
        #expect(store.double(for: .readerLineSpacing) == nil)
        #expect(store.string(for: .readerFont) == nil)
        #expect(store.string(for: .readerAyahMarkerStyle) == nil)

        #expect(settings.paper == .system)
        #expect(settings.typography == .fallback)
        #expect(settings.font == .kfgqpcHafs)
        #expect(settings.markerStyle == .style1)
        #expect(settings.hasChoices == false)
    }

    // MARK: Resolving a style

    /// `.system` is the case that has no colours of its own, and the one a wrong answer would be
    /// least visible in — so it is worth pinning that it really does hand back the theme's.
    @Test func systemPaperResolvesToTheAppsOwnPalette() {
        let settings = ReaderSettings(settingsStore: InMemorySettingsStore())
        let theme = Theme(accent: .sapphire)

        let style = settings.style(on: theme)

        #expect(style.palette.background == theme.background)
        #expect(style.palette.textPrimary == theme.textPrimary)
        #expect(style.palette.accent == theme.accent)
        #expect(style.typography == .fallback)
    }

    /// A named paper fixes its own ink, including the accent — the app's accent is chosen
    /// against the app's background and washes out on parchment. See `ReadingPalette`.
    @Test func namedPaperReplacesTheAccentToo() {
        let store = InMemorySettingsStore(strings: [.readerPaper: ReaderPaper.parchment.rawValue])
        let settings = ReaderSettings(settingsStore: store)
        let theme = Theme(accent: .sapphire)

        let style = settings.style(on: theme)

        #expect(style.palette.background != theme.background)
        #expect(style.palette.accent != theme.accent)
    }

    @Test func everyPaperResolvesToADistinctPage() {
        let theme = Theme()
        let backgrounds = ReaderPaper.allCases.map { theme.reading($0).background }

        #expect(Set(backgrounds).count == ReaderPaper.allCases.count)
    }
}
