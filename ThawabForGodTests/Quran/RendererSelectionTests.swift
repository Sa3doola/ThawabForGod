//
//  RendererSelectionTests.swift
//  ThawabForGodTests
//

import CoreGraphics
import Foundation
import Testing
@testable import ThawabForGod

/// Ported from Mushaf's `RendererSelectionTests` (Phase 2.3): which renderer a page uses, the
/// Unicode fallback, and that the glyph renderer never leaks glyph codes into VoiceOver or copied
/// text. V2 glyph codes are Arabic Presentation Forms-A characters (U+FB50–U+FDFF), which would
/// read and paste as wrong Arabic; the Hafs text never uses that block.
///
/// Serialised because page-font registration is process-wide. The `-debugRenderer` launch option
/// is gone: the override is the `forced:` parameter, which these tests pass directly.
@Suite(.serialized) @MainActor
struct RendererSelectionTests {
    let style = MushafStyle.madaniV2

    private static var fullRepository: QuranRepository { QuranTestData.repository(QuranTestData.fullDatabase) }

    @Test func glyphPagesUseTheirOwnFontOnceRegistered() {
        #expect(style.renderer == .glyphPerPage)
        #expect(PageRenderer.select(style: style, page: 50, forced: nil, status: .registered) == .glyph(fontName: "QCF2050"))
        #expect(PageRenderer.select(style: style, page: 604, forced: nil, status: .registered) == .glyph(fontName: "QCF2604"))
    }

    @Test func pendingFontWaitsAndUnavailableFontFallsBack() {
        #expect(PageRenderer.select(style: style, page: 50, forced: nil, status: .pending) == nil)
        #expect(PageRenderer.select(style: style, page: 50, forced: nil, status: .unavailable) == .unicode)
    }

    @Test func debugOverrideForcesEitherRenderer() {
        #expect(PageRenderer.select(style: style, page: 50, forced: .unicode, status: .registered) == .unicode)
        #expect(PageRenderer.select(style: style, page: 50, forced: .glyphPerPage, status: .registered) == .glyph(fontName: "QCF2050"))
        // Forcing glyphs cannot bring back a missing font.
        #expect(PageRenderer.select(style: style, page: 50, forced: .glyphPerPage, status: .unavailable) == .unicode)
    }

    @Test func rendererMetricsDiffer() {
        #expect(PageRenderer.glyph(fontName: "QCF2050").metrics == .glyphPerPage)
        #expect(PageRenderer.unicode.metrics == .unicode)
        #expect(RendererMetrics.glyphPerPage.minimumGapEm < RendererMetrics.unicode.minimumGapEm)
        // Measured in Phase 2.4: the smallest pitches with no touching lines on any page.
        #expect(RendererMetrics.glyphPerPage == RendererMetrics(minimumGapEm: 0.1, slotHeightEm: 2.0))
        #expect(RendererMetrics.unicode == RendererMetrics(minimumGapEm: 0.22, slotHeightEm: 1.7))
    }

    /// A page whose font file is missing is drawn (and measured) with the Unicode renderer.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func missingPageFontFallsBackToUnicode() async throws {
        // A folder with no page fonts in it at all.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("no-fonts-\(UUID().uuidString)")
        let store = FontPackStore(root: root)
        let renderer = await PageRenderer.resolve(style: style, page: 50, forced: nil, store: store)
        #expect(renderer == .unicode)
        #expect(store.status(page: 50, style: .madaniV2) == .unavailable)

        let corpus = try await Self.fullRepository.loadCorpus(style: .madaniV2)
        let page = try #require(corpus.page(50))
        let measurement = await PageMetricsCache().measurement(
            for: page, style: .madaniV2, basmala: corpus.basmala, faces: QuranFaces.launch, renderer: renderer
        )
        #expect(measurement.lineWidths.values.allSatisfy { $0 > 0 })
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func resolveRegistersTheBundledPageFont() async {
        let store = FontPackStore()
        #expect(await PageRenderer.resolve(style: style, page: 420, forced: nil, store: store) == .glyph(fontName: "QCF2420"))
        #expect(store.status(page: 420, style: .madaniV2) == .registered)
        // One page only: the window is the pager's job.
        #expect(store.registeredPages(style: .madaniV2) == [420])
        await store.ensureRegistered(around: 600, style: style)
        #expect(!store.isRegistered(page: 420, style: .madaniV2))
    }

    /// Glyph widths come from the page font: different from the Hafs widths, keyed apart.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func glyphMeasurementUsesThePageFont() async throws {
        let corpus = try await Self.fullRepository.loadCorpus(style: .madaniV2)
        let page = try #require(corpus.page(187))
        let faces = QuranFaces.launch
        let store = FontPackStore()
        let glyph = await PageRenderer.resolve(style: style, page: 187, forced: nil, store: store)
        #expect(glyph == .glyph(fontName: "QCF2187"))
        let cache = PageMetricsCache()
        let glyphWidths = await cache.measurement(for: page, style: .madaniV2, basmala: corpus.basmala, faces: faces, renderer: glyph)
        let hafsWidths = await cache.measurement(for: page, style: .madaniV2, basmala: corpus.basmala, faces: faces, renderer: .unicode)
        #expect(cache.count == 2)
        #expect(glyphWidths != hafsWidths)
        #expect(Set(glyphWidths.lineWidths.keys) == Set(hafsWidths.lineWidths.keys))
        #expect(glyphWidths.lineWidths.values.allSatisfy { $0 > 0 })
        #expect(PageMetricsCache.Key(style: .madaniV2, page: 187, faces: faces, renderer: glyph)
                != PageMetricsCache.Key(style: .madaniV2, page: 187, faces: faces, renderer: .unicode))
        await store.ensureRegistered(around: 600, style: style)
    }

    /// Every segment carries one glyph per Hafs word, and a marker glyph exactly when the ayah
    /// ends on the line.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func segmentsCarryGlyphsBesideTheHafsText() async throws {
        let corpus = try await Self.fullRepository.loadCorpus(style: .madaniV2)
        var segments = 0
        for page in corpus.pages {
            for segment in page.lines.flatMap(\.segments) {
                segments += 1
                #expect(segment.glyphs.count == segment.words.count, "\(segment.reference) p\(page.number)")
                #expect((segment.markerGlyph != nil) == segment.endsAyah, "\(segment.reference) p\(page.number)")
                #expect(segment.markerText == (segment.endsAyah ? Self.arabicIndic(segment.verse) : nil), "\(segment.reference)")
                #expect(segment.words.allSatisfy { !Self.isGlyphCode($0) }, "\(segment.reference)")
                #expect(segment.glyphs.allSatisfy(Self.isGlyphCode), "\(segment.reference)")
            }
        }
        #expect(segments > 9000)
    }

    /// The glyph renderer's items are the glyph codes, markers included, each tied to its ayah.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func glyphLineItemsIncludeTheMarkerGlyph() async throws {
        let corpus = try await Self.fullRepository.loadCorpus(style: .madaniV2)
        let line = try #require(corpus.page(50)?.lines.first { $0.kind == .text })
        let glyphItems = LineItem.items(for: line, renderer: .glyph(fontName: "QCF2050"))
        let hafsItems = LineItem.items(for: line, renderer: .unicode)
        #expect(glyphItems.map(\.ayah) == hafsItems.map(\.ayah))
        #expect(glyphItems.allSatisfy { Self.isGlyphCode($0.text) })
        // The Unicode renderer's marker is the marker word's Hafs text: Arabic-Indic digits.
        #expect(hafsItems.map(\.text).contains("\u{0661}"))
        #expect(hafsItems.allSatisfy { !Self.isGlyphCode($0.text) })
    }

    /// VoiceOver reads the Hafs words of the page and copying uses `Ayah.text`: no glyph codes.
    /// Separated mode and the ayah sheet end each ayah with its marker word's Hafs text.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func ayahsCarryTheirMarkerText() async throws {
        let database = QuranTestData.fullDatabase
        let corpus = try await QuranTestData.repository(database).loadCorpus(style: .madaniV2)
        #expect(corpus.ayah(VerseReference(surah: 2, verse: 255))?.marker == "\u{0662}\u{0665}\u{0665}")
        #expect(corpus.ayahs.allSatisfy { $0.marker == Self.arabicIndic($0.id.verse) })
        let kahf = try await QuranTestData.repository(database).ayahs(surah: 18, style: .madaniV2)
        #expect(kahf.last?.marker == "\u{0661}\u{0661}\u{0660}")
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func accessibilityAndCopyUseHafsText() async throws {
        let corpus = try await Self.fullRepository.loadCorpus(style: .madaniV2)
        let page = try #require(corpus.page(50))
        let id = VerseReference(surah: 3, verse: 7)
        let spoken = page.lines.flatMap(\.segments).filter { $0.reference == id }.flatMap(\.words).joined(separator: " ")
        #expect(spoken == corpus.ayah(id)?.text)
        #expect(!spoken.unicodeScalars.contains { (0xFB50...0xFDFF).contains($0.value) })
    }

    static func arabicIndic(_ number: Int) -> String {
        String(String(number).unicodeScalars.map { Character(Unicode.Scalar($0.value - 0x30 + 0x0660)!) })
    }

    /// Entirely Arabic Presentation Forms-A, as every `glyph_v2` code is.
    static func isGlyphCode(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy { (0xFB50...0xFDFF).contains($0.value) }
    }
}

/// Ported from Mushaf's `LineTapTests` (Phase 2.3): taps in the gap between two items select the
/// nearest item's ayah.
struct LineTapTests {
    let a = VerseReference(surah: 3, verse: 1), b = VerseReference(surah: 3, verse: 2)

    @Test func tapsInGapsGoToTheNearestItem() {
        // Laid out right to left: b's word on the left, a's marker and word on the right.
        let frames = [(a, CGRect(x: 80, y: 0, width: 20, height: 10)), (a, CGRect(x: 60, y: 0, width: 18, height: 10)),
                      (b, CGRect(x: 10, y: 0, width: 40, height: 10))]
        #expect(LineItemBounds.nearest(to: 90, in: frames) == a)   // inside a word
        #expect(LineItemBounds.nearest(to: 79, in: frames) == a)   // gap within ayah a
        #expect(LineItemBounds.nearest(to: 56, in: frames) == a)   // gap, nearer a's marker
        #expect(LineItemBounds.nearest(to: 53, in: frames) == b)   // gap, nearer b
        #expect(LineItemBounds.nearest(to: 0, in: frames) == b)    // left margin
        #expect(LineItemBounds.nearest(to: 50, in: []) == nil)
    }
}
