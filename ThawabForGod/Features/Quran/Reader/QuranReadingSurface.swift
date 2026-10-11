//
//  QuranReadingSurface.swift
//  ThawabForGod
//

import SwiftUI

/// The Quran as the reader sees it right now: the Mushaf pager or the separated list, whichever the
/// settings and the build allow, drawn in the reader's theme.
///
/// The one place both readers get what they share, so neither can drift: the resolved page colours
/// (`\.readingPalette`, following the system into Dark if asked), the faces that registered, the
/// separated face (`\.readingStyle`), the surah-header frame glyph, and keeping the screen awake.
/// `QuranReaderView` puts its toolbar, bars and navigation around this; the panel arrives with M5.3.
struct QuranReadingSurface: View {
    let corpus: QuranCorpus
    let settings: QuranReaderSettings
    let faces: QuranFaces
    let services: MushafRenderServices
    /// Where the Mushaf pager is.
    let mushaf: MushafReadingState
    /// The surah separated mode shows, and the ayah to open it at.
    let separatedSurah: Int
    var separatedAyah: VerseReference?
    /// A jump inside the surah on screen; a different surah is a new list, opened at `separatedAyah`.
    var separatedScrollRequest: SeparatedScrollRequest? = nil
    var marks: QuranAyahMarks = .none
    let translations: SeparatedTranslationsModel
    let onSelect: (VerseReference) -> Void
    var onSeparatedTopAyahChange: (VerseReference) -> Void = { _ in }
    var onNextSurah: (Int) -> Void = { _ in }
    var onShowSurahInfo: ((Int) -> Void)? = nil

    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.theme) private var theme

    var body: some View {
        let palette = theme.reading(settings.resolvedTheme(systemColorScheme: systemColorScheme))
        content
            .environment(settings)
            .environment(\.readingPalette, palette)
            .environment(\.readingStyle, ReadingStyle(font: settings.font))
            .environment(\.quranFaces, faces)
            .environment(\.surahHeaderFrame, corpus.surahHeaderFrame)
            // Menus, scroll indicators and the status bar over the page follow the page, not the app.
            .environment(\.colorScheme, palette.colorScheme)
            .background(palette.background)
            .keepScreenAwake(settings.keepsScreenAwake)
    }

    @ViewBuilder
    private var content: some View {
        switch settings.displayMode {
        case .mushaf where corpus.hasPages:
            MushafPagerView(
                corpus: corpus,
                state: mushaf,
                settings: settings,
                services: services,
                marks: marks,
                onSelect: onSelect
            )
        case .mushaf, .separated:
            if let surah = corpus.surah(separatedSurah) {
                SeparatedReaderView(
                    surah: surah,
                    ayahs: corpus.ayahs(inSurah: separatedSurah),
                    basmala: corpus.basmala,
                    selectedAyah: mushaf.selectedAyah,
                    marks: marks,
                    initialAyah: separatedAyah,
                    scrollRequest: separatedScrollRequest,
                    onSelect: onSelect,
                    onTopAyahChange: onSeparatedTopAyahChange,
                    translations: translations,
                    nextSurah: corpus.surah(separatedSurah + 1),
                    onNextSurah: onNextSurah,
                    onShowSurahInfo: onShowSurahInfo
                )
                // A new surah starts at its own top rather than at the last one's scroll offset.
                .id(separatedSurah)
            }
        }
    }
}
