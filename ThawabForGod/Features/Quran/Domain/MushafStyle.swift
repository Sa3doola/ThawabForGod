//
//  MushafStyle.swift
//  ThawabForGod
//

import CoreGraphics
import Foundation

/// A printed Mushaf layout the app can show. The raw value is the `style` column in
/// `quran-mushaf.sqlite` (`mushaf_line`, `mushaf_page`, `marker`).
nonisolated enum MushafStyleID: String, Codable, CaseIterable, Sendable {
    /// KFGQPC V2, 1421H print: the Madinah Mushaf. The default.
    case madaniV2
}

/// Everything that differs between Mushaf layouts. Code reads page and line counts from here,
/// never from literals.
nonisolated struct MushafStyle: Sendable, Hashable, Identifiable {
    let id: MushafStyleID
    let pageCount: Int
    /// Line slots on a full page.
    let linesPerPage: Int
    /// Pages with fewer lines than `linesPerPage`: they keep the full slot height and sit in the
    /// middle of the page.
    let shortPages: Set<Int>
    /// Width ÷ height of a printed page; wide screens never stretch a page beyond it.
    let pageAspectRatio: CGFloat
    /// How pages are drawn. A page whose font is missing falls back to `.unicode`.
    let renderer: RendererKind
    /// Draws a whole surah header line (frame and name) from `Surah.headerGlyph`.
    let headerFont: QuranFace
    /// Calligraphic surah names (`Surah.nameGlyph`) outside the Mushaf page.
    let surahNameFont: QuranFace
    /// One font per page, bundled (QPC V2); nil for styles drawn with a single font.
    let pageFonts: PageFontPack?

    /// The page fonts' folder is `QuranPageFonts.folderName`, the one name `FontRegistrar` skips
    /// at launch and the page-font store reads from (T1, T14).
    static let madaniV2 = MushafStyle(
        id: .madaniV2,
        pageCount: 604,
        linesPerPage: 15,
        shortPages: [1, 2],
        pageAspectRatio: 0.7,
        renderer: .glyphPerPage,
        headerFont: .surahHeader,
        surahNameFont: .surahName,
        pageFonts: PageFontPack(directory: QuranPageFonts.folderName, fileNameFormat: "p%d", postScriptNameFormat: "QCF2%03d")
    )

    init(
        id: MushafStyleID, pageCount: Int, linesPerPage: Int, shortPages: Set<Int>, pageAspectRatio: CGFloat,
        renderer: RendererKind, headerFont: QuranFace, surahNameFont: QuranFace, pageFonts: PageFontPack?
    ) {
        self.id = id
        self.pageCount = pageCount
        self.linesPerPage = linesPerPage
        self.shortPages = shortPages
        self.pageAspectRatio = pageAspectRatio
        self.renderer = renderer
        self.headerFont = headerFont
        self.surahNameFont = surahNameFont
        self.pageFonts = pageFonts
    }

    init(_ id: MushafStyleID) {
        switch id {
        case .madaniV2: self = .madaniV2
        }
    }

    var pages: ClosedRange<Int> { 1...pageCount }
}

/// How a style draws its Mushaf pages.
nonisolated enum RendererKind: String, Sendable, Hashable, CaseIterable {
    /// One font per page (`MushafStyle.pageFonts`); every word, ayah marker included, is one glyph
    /// (`glyph_v2`). Print-exact.
    case glyphPerPage
    /// The Hafs Unicode text (`text_hafs`) in one font, `QuranFace.ayahText`.
    case unicode
}

/// A style's page fonts: one TTF per page in a bundle folder (a folder reference, so the files keep
/// their subfolder), registered on demand by the page-font store.
nonisolated struct PageFontPack: Sendable, Hashable {
    /// Folder in the app bundle's resources.
    let directory: String
    /// File name of a page's font without extension, e.g. "p%d" → "p50".
    let fileNameFormat: String
    /// PostScript name of a page's font, e.g. "QCF2%03d" → "QCF2050". Checked against the file.
    let postScriptNameFormat: String

    func fileName(page: Int) -> String {
        String(format: fileNameFormat, page)
    }

    func postScriptName(page: Int) -> String {
        String(format: postScriptNameFormat, page)
    }
}
