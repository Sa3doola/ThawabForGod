//
//  QuranReaderSettingsTests.swift
//  ThawabForGodTests
//

import SwiftUI
import Testing
@testable import ThawabForGod

/// The reading settings (D4): what a reader gets before choosing anything, that choosing one thing
/// writes one key, that the Mushaf mode is only offered where the database can draw it, and that a
/// choice survives a relaunch.
@MainActor
struct QuranReaderSettingsTests {

    private static let fullData: QuranCapabilities = [.text, .words, .mushafPages, .glyphV2, .fontLigatures]

    /// Every key the settings own, read back from the store whatever type it was written as.
    private static func storedKeys(in store: InMemorySettingsStore) -> Set<SettingsKey> {
        var keys = Set<SettingsKey>()
        for key in QuranReaderSettings.stringKeys where store.string(for: key) != nil { keys.insert(key) }
        for key in QuranReaderSettings.boolKeys where store.bool(for: key) != nil { keys.insert(key) }
        for key in QuranReaderSettings.doubleKeys where store.double(for: key) != nil { keys.insert(key) }
        return keys
    }

    // MARK: Defaults

    @Test func defaultsAreMushafsExceptTheKeptNoorChoices() {
        let settings = QuranReaderSettings(settingsStore: InMemorySettingsStore(), capabilities: Self.fullData)

        #expect(settings.displayMode == .mushaf)
        #expect(settings.theme == .paper)
        #expect(settings.followsSystemAppearance)
        #expect(settings.textSize == 28)
        #expect(settings.font == .kfgqpcHafs)
        #expect(!settings.keepsScreenAwake, "an app that quietly stopped a phone sleeping drains a battery nobody consented to")
        #expect(settings.showsMarginMarkers)
        #expect(settings.showsTranslationInSeparated)
        #expect(settings.phoneLandscape == .onePage)
        #expect(settings.flatOpen == .spread)
    }

    @Test func readingTheDefaultsWritesNothing() {
        let store = InMemorySettingsStore()
        let settings = QuranReaderSettings(settingsStore: store, capabilities: Self.fullData)
        _ = settings.displayMode
        _ = settings.resolvedTheme(systemColorScheme: .dark)
        settings.apply(.text)

        #expect(Self.storedKeys(in: store).isEmpty)
    }

    // MARK: Writes only what was chosen

    @Test func eachChoiceWritesItsOwnKeyAndNoOther() {
        let cases: [(SettingsKey, (QuranReaderSettings) -> Void)] = [
            (.quranDisplayMode, { $0.select(displayMode: .separated) }),
            (.quranReaderTheme, { $0.select(theme: .sepia) }),
            (.quranFollowsSystemAppearance, { $0.setFollowsSystemAppearance(false) }),
            (.readerTextSize, { $0.enlargeText() }),
            (.readerFont, { $0.select(font: .amiriQuran) }),
            (.readerKeepsScreenAwake, { $0.setKeepsScreenAwake(true) }),
            (.quranShowsMarginMarkers, { $0.setShowsMarginMarkers(false) }),
            (.quranShowsTranslationInSeparated, { $0.setShowsTranslationInSeparated(false) }),
            (.quranPhoneLandscape, { $0.select(phoneLandscape: .twoPages) }),
            (.quranFlatOpen, { $0.select(flatOpen: .singlePage) }),
        ]
        for (key, choose) in cases {
            let store = InMemorySettingsStore()
            choose(QuranReaderSettings(settingsStore: store, capabilities: Self.fullData))
            #expect(Self.storedKeys(in: store) == [key], "\(key)")
        }
    }

    @Test func choosingTheDefaultValueStillRecordsTheChoice() {
        // A reader who picks Paper has made a choice, even if it is today's default: it must
        // outlast a later build that changes the default.
        let store = InMemorySettingsStore()
        QuranReaderSettings(settingsStore: store).select(theme: .paper)
        #expect(store.string(for: .quranReaderTheme) == "paper")
    }

    @Test func resetRemovesEveryKeyRatherThanWritingDefaults() {
        let store = InMemorySettingsStore()
        let settings = QuranReaderSettings(settingsStore: store, capabilities: Self.fullData)
        settings.select(displayMode: .separated)
        settings.select(theme: .dark)
        settings.setFollowsSystemAppearance(false)
        settings.setTextSize(40)
        settings.select(font: .amiriQuran)
        settings.setKeepsScreenAwake(true)
        settings.setShowsMarginMarkers(false)
        settings.setShowsTranslationInSeparated(false)
        settings.select(phoneLandscape: .twoPages)
        settings.select(flatOpen: .singlePage)

        settings.reset()

        #expect(Self.storedKeys(in: store).isEmpty)
        #expect(settings.displayMode == .mushaf)
        #expect(settings.theme == .paper)
        #expect(settings.textSize == QuranReaderSettings.defaultTextSize)
        #expect(!settings.keepsScreenAwake)
    }

    // MARK: Capabilities

    @Test func theTanzilBuildOffersOnlySeparatedMode() {
        let settings = QuranReaderSettings(settingsStore: InMemorySettingsStore(), capabilities: .text)
        #expect(settings.availableDisplayModes == [.separated])
        #expect(settings.displayMode == .separated)
    }

    @Test func mushafCannotBeChosenWhereItCannotBeDrawn() {
        let store = InMemorySettingsStore()
        let settings = QuranReaderSettings(settingsStore: store, capabilities: .text)
        settings.select(displayMode: .mushaf)

        #expect(settings.displayMode == .separated)
        #expect(store.string(for: .quranDisplayMode) == nil, "a choice the reader was never offered is not stored")
    }

    @Test func aStoredMushafChoiceSurvivesABuildThatCannotDrawIt() {
        // Full data → public build → full data again: the stored choice is kept, not overwritten.
        let store = InMemorySettingsStore(strings: [.quranDisplayMode: "mushaf"])
        let settings = QuranReaderSettings(settingsStore: store, capabilities: .text)
        #expect(settings.displayMode == .separated)

        settings.apply(Self.fullData)
        #expect(settings.displayMode == .mushaf)
        #expect(store.string(for: .quranDisplayMode) == "mushaf")
    }

    @Test func theFullBuildOffersMushafFirst() {
        let settings = QuranReaderSettings(settingsStore: InMemorySettingsStore(), capabilities: Self.fullData)
        #expect(settings.availableDisplayModes == [.mushaf, .separated])
    }

    // MARK: Round trip

    @Test func everyChoiceSurvivesARelaunch() {
        let store = InMemorySettingsStore()
        let first = QuranReaderSettings(settingsStore: store, capabilities: Self.fullData)
        first.select(displayMode: .separated)
        first.select(theme: .sepia)
        first.setFollowsSystemAppearance(false)
        first.setTextSize(36)
        first.select(font: .amiriQuran)
        first.setKeepsScreenAwake(true)
        first.setShowsMarginMarkers(false)
        first.setShowsTranslationInSeparated(false)
        first.select(phoneLandscape: .twoPages)
        first.select(flatOpen: .singlePage)

        let second = QuranReaderSettings(settingsStore: store, capabilities: Self.fullData)
        #expect(second.displayMode == .separated)
        #expect(second.theme == .sepia)
        #expect(!second.followsSystemAppearance)
        #expect(second.textSize == 36)
        #expect(second.font == .amiriQuran)
        #expect(second.keepsScreenAwake)
        #expect(!second.showsMarginMarkers)
        #expect(!second.showsTranslationInSeparated)
        #expect(second.phoneLandscape == .twoPages)
        #expect(second.flatOpen == .singlePage)
    }

    @Test func unknownStoredValuesFallBack() {
        let store = InMemorySettingsStore(
            strings: [.quranDisplayMode: "scroll", .quranReaderTheme: "night", .readerFont: "indoPak",
                      .quranPhoneLandscape: "three", .quranFlatOpen: "tent"],
            doubles: [.readerTextSize: .nan]
        )
        let settings = QuranReaderSettings(settingsStore: store, capabilities: Self.fullData)
        #expect(settings.displayMode == .mushaf)
        #expect(settings.theme == .paper)
        #expect(settings.font == .kfgqpcHafs)
        #expect(settings.phoneLandscape == .onePage)
        #expect(settings.flatOpen == .spread)
        #expect(settings.textSize == QuranReaderSettings.defaultTextSize)
    }

    @Test func textSizeIsClampedOnTheWayInAndOut() {
        let store = InMemorySettingsStore(doubles: [.readerTextSize: 200])
        let settings = QuranReaderSettings(settingsStore: store)
        #expect(settings.textSize == 48)
        #expect(!settings.canEnlargeText)

        settings.setTextSize(4)
        #expect(settings.textSize == 18)
        #expect(store.double(for: .readerTextSize) == 18)
        #expect(!settings.canShrinkText)
    }

    // MARK: Theme resolution

    @Test func followingTheSystemOnlyEverSwapsToDark() {
        let store = InMemorySettingsStore()
        let settings = QuranReaderSettings(settingsStore: store)
        settings.select(theme: .sepia)

        #expect(settings.resolvedTheme(systemColorScheme: .light) == .sepia)
        #expect(settings.resolvedTheme(systemColorScheme: .dark) == .dark)

        settings.setFollowsSystemAppearance(false)
        #expect(settings.resolvedTheme(systemColorScheme: .dark) == .sepia)
    }
}
