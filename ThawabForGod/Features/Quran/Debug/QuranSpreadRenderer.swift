//
//  QuranSpreadRenderer.swift
//  ThawabForGod
//

#if DEBUG
import ImageIO
import OSLog
import SwiftUI

/// `-quranRenderSpread 1210x834 -quranPage 50` renders the pager unit holding that page at the
/// given point size into Documents/spread.png.
///
/// Ported from Mushaf's `DebugSpreadRenderer`, and for the same reason: a spread needs a landscape
/// iPad or a fold, and neither can be produced from the command line — iPadOS refuses a
/// programmatic rotation while multitasking is on. DEBUG only.
@MainActor
enum QuranSpreadRenderer {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ThawabForGod", category: "Debug")

    static func render(
        corpus: QuranCorpus, state: MushafReadingState, size: CGSize, services: MushafRenderServices, faces: QuranFaces,
        settings: QuranReaderSettings, l10n: LocalizationManager, forced: RendererKind?, palette: ReadingPalette
    ) async {
        let unit = MushafPageUnit.resolve(size: size)
        let first = unit.unitStart(for: state.page)
        // ImageRenderer draws one pass without running tasks: register the page fonts and measure
        // the pages first, with the renderer each page will use.
        for number in first..<(first + unit.pageCount) {
            guard let page = corpus.page(number) else { continue }
            let renderer = await PageRenderer.resolve(style: corpus.style, page: number, forced: forced, store: services.pageFonts)
            _ = await services.metricsCache.measurement(
                for: page, style: corpus.style.id, basmala: corpus.basmala, faces: faces, renderer: renderer
            )
        }

        let content = MushafUnitView(
            corpus: corpus, state: state, settings: settings, services: services, firstPage: first, unit: unit, onSelect: { _ in }
        )
        .frame(width: size.width, height: size.height)
        .background(palette.background)
        .environment(l10n)
        .environment(\.appFont, PlexAppFont())
        .environment(\.quranFaces, faces)
        .environment(\.surahHeaderFrame, corpus.surahHeaderFrame)
        .environment(\.forcedRenderer, forced)
        .environment(\.readingPalette, palette)
        .environment(\.layoutDirection, .rightToLeft)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let destination = CGImageDestinationCreateWithURL(
                  directory.appendingPathComponent("spread.png") as CFURL, "public.png" as CFString, 1, nil
              )
        else {
            logger.error("Spread render failed")
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        logger.info("Rendered \(unit.pageCount) page(s) at \(Int(size.width))x\(Int(size.height)) to Documents/spread.png")
        print("QuranSpreadRenderer done")
    }
}
#endif
