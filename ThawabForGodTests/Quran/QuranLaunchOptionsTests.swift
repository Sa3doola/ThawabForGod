//
//  QuranLaunchOptionsTests.swift
//  ThawabForGodTests
//

#if DEBUG
import CoreGraphics
import Testing
@testable import ThawabForGod

/// The DEBUG launch options the Quran's UI tests and captures drive the reader with (Q2).
@MainActor
struct QuranLaunchOptionsTests {

    @Test func aPlainLaunchHasNoTargetAndChangesNothing() {
        let options = QuranLaunchOptions(arguments: ["ThawabForGod", "-AppleLanguages", "(en)"])
        #expect(options.readerTarget == nil)

        let store = InMemorySettingsStore()
        options.apply(to: QuranReaderSettings(settingsStore: store))
        #expect(store.string(for: .quranReaderTheme) == nil)
        #expect(store.string(for: .quranDisplayMode) == nil)
    }

    @Test func parsesEveryOption() {
        let options = QuranLaunchOptions(arguments: [
            "app", "-quranPage", "50", "-quranMode", "mushaf", "-quranTheme", "sepia", "-quranFollowSystem", "NO",
            "-quranSelect", "2:255", "-quranRenderer", "unicode", "-quranMarginMarkers", "NO",
            "-quranFont", "amiriQuran", "-quranTextSize", "32", "-quranFold", "0.55,24", "-quranResetSettings", "YES",
        ])
        #expect(options.readerTarget == .page(50))
        #expect(options.displayMode == .mushaf)
        #expect(options.theme == .sepia)
        #expect(options.followsSystemAppearance == false)
        #expect(options.selectedAyah == VerseReference(surah: 2, verse: 255))
        #expect(options.renderer == .unicode)
        #expect(options.showsMarginMarkers == false)
        #expect(options.font == .amiriQuran)
        #expect(options.textSize == 32)
        #expect(options.foldOverride == FoldGeometry.DebugOverride(axis: .vertical, argument: "0.55,24"))
        #expect(options.resetsSettings)
    }

    @Test func aPageIsTheReaderTarget() {
        #expect(QuranLaunchOptions(arguments: ["-quranPage", "50"]).readerTarget == .page(50))
    }

    @Test func aSurahIsTheReaderTarget() {
        #expect(QuranLaunchOptions(arguments: ["-quranSurah", "2"]).readerTarget == .surah(2))
    }

    @Test func aSurahWithAnAyahIsThatAyahTarget() {
        let options = QuranLaunchOptions(arguments: ["-quranSurah", "2", "-quranAyah", "255"])
        #expect(options.readerTarget == .ayah(VerseReference(surah: 2, verse: 255)))
    }

    @Test func aPageWinsOverASurah() {
        #expect(QuranLaunchOptions(arguments: ["-quranSurah", "2", "-quranPage", "3"]).readerTarget == .page(3))
    }

    @Test func anOutOfRangeSurahHasNoTarget() {
        #expect(QuranLaunchOptions(arguments: ["-quranSurah", "115"]).readerTarget == nil)
    }

    @Test func aTrailingOptionWithNoValueHasNoTarget() {
        #expect(QuranLaunchOptions(arguments: ["-quranPage"]).readerTarget == nil)
    }

    @Test func immersiveIsOffUnlessAskedFor() {
        #expect(!QuranLaunchOptions(arguments: []).startsImmersive)
        #expect(!QuranLaunchOptions(arguments: ["-quranImmersive", "NO"]).startsImmersive)
        #expect(QuranLaunchOptions(arguments: ["-quranImmersive", "YES"]).startsImmersive)
    }

    @Test func dataPublicReadsTheTanzilDatabase() {
        #expect(QuranLaunchOptions(arguments: ["-quranData", "public"]).usesPublicData)
    }

    /// Any value other than `public` leaves the bundled database in use.
    @Test func otherDataValuesKeepTheBundledDatabase() {
        #expect(!QuranLaunchOptions(arguments: ["-quranData", "full"]).usesPublicData)
        #expect(!QuranLaunchOptions(arguments: ["-quranData"]).usesPublicData)
        #expect(!QuranLaunchOptions(arguments: []).usesPublicData)
    }

    @Test func measurementOptions() {
        let options = QuranLaunchOptions(arguments: ["-quranRenderSpread", "1210x834", "-quranPageThrough", "YES", "-quranPageThroughEvery", "25"])
        #expect(options.spreadRenderSize == CGSize(width: 1210, height: 834))
        #expect(options.pagesThrough)
        #expect(options.pageThroughEvery == 25)

        let defaults = QuranLaunchOptions(arguments: ["-quranRenderSpread", "wide", "-quranPageThroughEvery", "0"])
        #expect(defaults.spreadRenderSize == nil)
        #expect(!defaults.pagesThrough)
        #expect(defaults.pageThroughEvery == 50)
    }

    @Test func aHorizontalFoldIsTabletop() {
        let options = QuranLaunchOptions(arguments: ["-quranFoldHorizontal", "0.5,24"])
        #expect(options.foldOverride?.axis == .horizontal)
    }

    @Test func malformedValuesAreIgnored() {
        let options = QuranLaunchOptions(arguments: ["-quranTheme", "night", "-quranMode", "scroll", "-quranFold", "wide", "-quranPage"])
        #expect(options.theme == nil)
        #expect(options.displayMode == nil)
        #expect(options.foldOverride == nil)
        #expect(options.readerTarget == nil, "a trailing option with no value")
    }

    @Test func applyResetsFirstThenWritesTheChoices() {
        let store = InMemorySettingsStore(strings: [.quranPhoneLandscape: "twoPages"])
        let settings = QuranReaderSettings(settingsStore: store, capabilities: [.text, .mushafPages])
        QuranLaunchOptions(arguments: ["-quranResetSettings", "YES", "-quranTheme", "dark", "-quranMode", "separated"])
            .apply(to: settings)

        #expect(store.string(for: .quranPhoneLandscape) == nil, "the reset ran")
        #expect(settings.theme == .dark)
        #expect(settings.displayMode == .separated)
    }

    // MARK: -quranLibrary and isQuranLaunch (M5.2)

    @Test func quranLibraryNamesAnIndex() {
        #expect(QuranLaunchOptions(arguments: ["-quranLibrary", "juz"]).libraryTab == .juz)
    }

    /// Each raw value names its own index, `page` included (it falls back to Surah in a build without pages).
    @Test func everyLibraryIndexHasItsOwnValue() {
        for tab in QuranLibraryTab.allCases {
            #expect(QuranLaunchOptions(arguments: ["-quranLibrary", tab.rawValue]).libraryTab == tab)
        }
        #expect(QuranLaunchOptions(arguments: ["-quranLibrary", "page"]).libraryTab == .page)
    }

    @Test func anUnknownLibraryIndexHasNoTab() {
        #expect(QuranLaunchOptions(arguments: ["-quranLibrary", "verse"]).libraryTab == nil)
        #expect(QuranLaunchOptions(arguments: ["-quranLibrary"]).libraryTab == nil)
    }

    @Test func aLibraryTabAloneIsAQuranLaunch() {
        let options = QuranLaunchOptions(arguments: ["-quranLibrary", "surah"])
        #expect(options.libraryTab == .surah)
        #expect(options.readerTarget == nil)
        #expect(options.isQuranLaunch)
    }

    @Test func aReaderTargetAloneIsAQuranLaunch() {
        let options = QuranLaunchOptions(arguments: ["-quranPage", "50"])
        #expect(options.libraryTab == nil)
        #expect(options.readerTarget == .page(50))
        #expect(options.isQuranLaunch)
    }

    @Test func aLibraryTabAndAReaderTargetTogetherAreAQuranLaunch() {
        let options = QuranLaunchOptions(arguments: ["-quranLibrary", "hizb", "-quranSurah", "2"])
        #expect(options.libraryTab == .hizb)
        #expect(options.readerTarget == .surah(2))
        #expect(options.isQuranLaunch)
    }

    @Test func aLaunchWithNeitherIsNotAQuranLaunch() {
        #expect(!QuranLaunchOptions(arguments: []).isQuranLaunch)
        #expect(!QuranLaunchOptions(arguments: ["-AppleLanguages", "(en)"]).isQuranLaunch)
    }

    /// An index name this build does not know names nothing, so it does not start the Quran tab either.
    @Test func anUnknownLibraryIndexIsNotAQuranLaunch() {
        #expect(!QuranLaunchOptions(arguments: ["-quranLibrary", "verse"]).isQuranLaunch)
    }
}
#endif
