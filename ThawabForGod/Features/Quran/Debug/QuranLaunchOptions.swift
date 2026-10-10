//
//  QuranLaunchOptions.swift
//  ThawabForGod
//

#if DEBUG
import CoreGraphics
import Foundation

/// Launch arguments that put the Quran reader in a known state, for the UI tests, the golden-page
/// captures and the performance runs of the Mushaf port (QURAN_MIGRATION_PLAN.md, Q2).
///
/// A slim version of Mushaf's 34 `-debug…` hooks, and **DEBUG only**: the whole type is compiled
/// out of a Release build, and nothing outside `#if DEBUG` names it. Each option is
/// `-quranSomething value`, e.g.
///
///     -quranPage 50 -quranMode mushaf -quranTheme sepia -quranFollowSystem NO
///     -quranSurah 2 -quranAyah 255 -quranMode separated
///
/// Read from the process's arguments rather than the `UserDefaults` argument domain: the values are
/// a scripted launch's, not preferences, and this project reads preferences through
/// `SettingsStore` alone. Options that are preferences (theme, mode, markers) are *applied* through
/// `QuranReaderSettings`, so they are written like a reader's choice would be; `-quranResetSettings`
/// runs first, so a capture never inherits the previous run's choices.
nonisolated struct QuranLaunchOptions: Equatable, Sendable {
    /// `-quranPage N`: open the Mushaf at page N.
    var page: Int?
    /// `-quranSurah N` (with optional `-quranAyah M`): open at that surah — its first page in Mushaf
    /// mode, the surah itself in separated mode.
    var surah: Int?
    var ayah: Int?
    /// `-quranSelect 2:255`: an ayah selected on arrival (the selection band).
    var selectedAyah: VerseReference?
    /// `-quranMode mushaf|separated`.
    var displayMode: QuranDisplayMode?
    /// `-quranTheme paper|sepia|dark`.
    var theme: ReaderTheme?
    /// `-quranFollowSystem YES|NO`: whether the system's Dark Mode swaps in the dark page.
    var followsSystemAppearance: Bool?
    /// `-quranRenderer glyph|unicode`: draw every page with this renderer when its font allows.
    var renderer: RendererKind?
    /// `-quranMarginMarkers YES|NO`.
    var showsMarginMarkers: Bool?
    /// `-quranFont kfgqpcHafs|amiriQuran` and `-quranTextSize 28`: separated mode's face and size.
    var font: ReaderFont?
    var textSize: Double?
    /// `-quranFold 0.55,24` (a vertical hinge at 55% with a 24 pt gutter; `0.5,0` is open flat) or
    /// `-quranFoldHorizontal 0.5,24` (tabletop): a fold the simulator cannot pose.
    var foldOverride: FoldGeometry.DebugOverride?
    /// `-quranResetSettings YES`: forget every reader choice before applying the rest.
    var resetsSettings = false
    /// `-quranRenderSpread 1210x834`: render the pager unit holding the target page at that point
    /// size into Documents/spread.png (`QuranSpreadRenderer`). iPadOS refuses a programmatic
    /// rotation under multitasking and a simulator cannot be turned from a script, so this is how a
    /// landscape spread is captured — the same way Mushaf captured its own.
    var spreadRenderSize: CGSize?
    /// `-quranPageThrough YES` (with `-quranPageThroughEvery N`, default 50): show every page in
    /// order and report memory (`PerformanceProbe`).
    var pagesThrough = false
    var pageThroughEvery = 50

    /// The options this process was launched with.
    static let current = QuranLaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String]) {
        var values: [String: String] = [:]
        for (index, argument) in arguments.enumerated() where argument.hasPrefix("-quran") && index + 1 < arguments.count {
            values[String(argument.dropFirst())] = arguments[index + 1]
        }
        func int(_ key: String) -> Int? { values[key].flatMap { Int($0) } }
        func bool(_ key: String) -> Bool? {
            switch values[key]?.lowercased() {
            case "yes", "true", "1": true
            case "no", "false", "0": false
            default: nil
            }
        }

        page = int("quranPage")
        surah = int("quranSurah").flatMap { (1...114).contains($0) ? $0 : nil }
        ayah = int("quranAyah")
        selectedAyah = values["quranSelect"].flatMap(VerseReference.init(parsing:))
        displayMode = values["quranMode"].flatMap(QuranDisplayMode.init(rawValue:))
        theme = values["quranTheme"].flatMap(ReaderTheme.init(rawValue:))
        followsSystemAppearance = bool("quranFollowSystem")
        renderer = switch values["quranRenderer"] {
        case "glyph": .glyphPerPage
        case "unicode": .unicode
        default: nil
        }
        showsMarginMarkers = bool("quranMarginMarkers")
        font = values["quranFont"].flatMap(ReaderFont.init(rawValue:))
        textSize = values["quranTextSize"].flatMap { Double($0) }
        foldOverride = values["quranFold"].flatMap { FoldGeometry.DebugOverride(axis: .vertical, argument: $0) }
            ?? values["quranFoldHorizontal"].flatMap { FoldGeometry.DebugOverride(axis: .horizontal, argument: $0) }
        resetsSettings = bool("quranResetSettings") ?? false
        spreadRenderSize = values["quranRenderSpread"].flatMap { spec in
            let parts = spec.split(separator: "x").compactMap { Double($0) }
            return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
        }
        pagesThrough = bool("quranPageThrough") ?? false
        pageThroughEvery = int("quranPageThroughEvery").flatMap { $0 > 0 ? $0 : nil } ?? 50
    }

    /// Where the launch asks the reader to open, if anywhere. A page wins over a surah.
    var target: QuranDebugTarget? {
        if let page { return .page(page) }
        if let surah { return .surah(surah, ayah: ayah) }
        return nil
    }

    /// Writes the options that are reader preferences, after a reset if one was asked for.
    @MainActor
    func apply(to settings: QuranReaderSettings) {
        if resetsSettings { settings.reset() }
        if let displayMode { settings.select(displayMode: displayMode) }
        if let theme { settings.select(theme: theme) }
        if let followsSystemAppearance { settings.setFollowsSystemAppearance(followsSystemAppearance) }
        if let showsMarginMarkers { settings.setShowsMarginMarkers(showsMarginMarkers) }
        if let font { settings.select(font: font) }
        if let textSize { settings.setTextSize(textSize) }
    }
}

/// Where the DEBUG reader opens.
nonisolated enum QuranDebugTarget: Hashable, Sendable, Identifiable {
    case page(Int)
    case surah(Int, ayah: Int?)

    var id: Self { self }
}
#endif
