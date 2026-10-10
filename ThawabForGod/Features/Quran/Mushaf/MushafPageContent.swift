//
//  MushafPageContent.swift
//  ThawabForGod
//

import SwiftUI

/// What drawing a Mushaf page needs beyond the page itself: the page-font store that decides the
/// renderer, and the cache that measures pages off the main actor. Both are `AppContainer`'s — one
/// of each per process — and are handed down explicitly from the pager rather than through the
/// environment, where a default would have to be a second instance.
struct MushafRenderServices {
    let pageFonts: any FontPackStoring
    let metricsCache: PageMetricsCache
}

/// The line area of one Mushaf page: equal slots, one per layout line. Ported from Mushaf.
struct MushafPageContent: View {
    let style: MushafStyle
    let page: MushafPage
    let basmala: String
    let surahs: [Surah]
    let services: MushafRenderServices
    let selectedAyah: VerseReference?
    /// Highlight colours of ayahs on this page.
    var highlights: [VerseReference: HighlightColor] = [:]
    /// Labels for the outer margin (empty when the setting is off).
    var marginMarkers: [MushafMarginMarker] = []
    /// Width of the page's side margin, where the labels are centred.
    var marginWidth: CGFloat = 0
    let onSelect: (VerseReference) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.quranFaces) private var faces
    @Environment(\.readingPalette) private var palette
    @Environment(\.mushafFontSizeCap) private var fontSizeCap
    @Environment(\.forcedRenderer) private var forcedRenderer

    @State private var elementFrames: [MushafPageElement: CGRect] = [:]
    /// Set when this view had to wait for its font or measurement; tagged with its key so a reused
    /// view never draws another page's widths.
    @State private var measured: (key: PageMetricsCache.Key, measurement: PageMeasurement)?

    /// What the task depends on: a new page, other faces or another forced renderer start over.
    private struct TaskKey: Hashable {
        let style: MushafStyleID, page: Int, faces: Set<QuranFace>, forced: RendererKind?
    }

    var body: some View {
        // The renderer the page can use right now; nil while its page font registers (the page
        // waits rather than flashing the Unicode text). Nothing is measured or registered here.
        let ready = PageRenderer.select(
            style: style, page: page.number, forced: forcedRenderer,
            status: services.pageFonts.status(page: page.number, style: style.id)
        )
        let drawn = drawable(ready: ready)
        GeometryReader { geometry in
            if let drawn {
                lines(measurement: drawn.measurement, renderer: drawn.key.renderer, size: geometry.size)
            }
        }
        .task(id: TaskKey(style: style.id, page: page.number, faces: faces.available, forced: forcedRenderer)) {
            // Always hand the result to the view, even when it is already cached: another request
            // (the pager's neighbour loop) can finish between this body reading the cache and this
            // task starting, and the cache itself does not trigger a redraw.
            let renderer = await PageRenderer.resolve(style: style, page: page.number, forced: forcedRenderer, store: services.pageFonts)
            let key = PageMetricsCache.Key(style: style.id, page: page.number, faces: faces, renderer: renderer)
            let measurement = await services.metricsCache.measurement(
                for: page, style: style.id, basmala: basmala, faces: faces, renderer: renderer
            )
            if measured?.key != key { measured = (key, measurement) }
        }
    }

    /// The measurement to draw with: this view's own (when it still matches the page and the ready
    /// renderer), else one measured earlier, so pages measured before draw in their first frame.
    private func drawable(ready: PageRenderer?) -> (key: PageMetricsCache.Key, measurement: PageMeasurement)? {
        if let measured, measured.key.style == style.id, measured.key.page == page.number,
           measured.key.faces == faces.available, ready == nil || measured.key.renderer == ready {
            return measured
        }
        guard let ready else { return nil }
        let key = PageMetricsCache.Key(style: style.id, page: page.number, faces: faces, renderer: ready)
        return services.metricsCache.cached(key).map { (key, $0) }
    }

    private func lines(measurement: PageMeasurement, renderer: PageRenderer, size: CGSize) -> some View {
        let metrics = MushafPageMetrics(
            page: page, measurement: measurement, size: size, slotCount: style.linesPerPage, fontSizeCap: fontSizeCap,
            renderer: renderer
        )
        return VStack(spacing: 0) {
            ForEach(page.lines) { line in
                lineView(line, metrics: metrics, renderer: renderer)
                    .frame(maxWidth: .infinity)
                    .frame(height: metrics.slotHeight)
            }
        }
        .overlay(alignment: .topLeading) {
            marginLabels(slotHeight: metrics.slotHeight, width: size.width)
        }
        .backgroundPreferenceValue(MushafElementBoundsKey.self) { anchors in
            GeometryReader { proxy in
                Color.clear.preference(key: MushafElementFramesKey.self, value: MushafElementFramesKey.frames(anchors, in: proxy))
            }
        }
        .onPreferenceChange(MushafElementFramesKey.self) { elementFrames = $0 }
        // VoiceOver reads the page per ayah, never per word: the synthetic children replace
        // everything drawn above.
        .accessibilityElement(children: .contain)
        .accessibilityChildren {
            MushafPageAccessibilityLayer(
                page: page,
                basmala: basmala,
                surahs: surahs,
                marginMarkers: marginMarkers,
                selectedAyah: selectedAyah,
                frames: elementFrames,
                onSelect: onSelect
            )
        }
        // Short pages (`style.shortPages`) keep the same slot height and sit in the middle.
        .frame(width: size.width, height: size.height)
        .preference(key: MushafFontSizeKey.self, value: metrics.fittedFontSize)
    }

    /// The margin labels beside their lines, in the outer margin: right on odd pages, left on even
    /// pages, as in the printed Mushaf whatever the interface language.
    private func marginLabels(slotHeight: CGFloat, width: CGFloat) -> some View {
        let isRightMargin = page.number % 2 == 1
        let x = isRightMargin ? width + marginWidth / 2 : -marginWidth / 2
        return ZStack(alignment: .topLeading) {
            ForEach(marginMarkers, id: \.self) { marker in
                if let index = page.lines.firstIndex(where: { $0.number == marker.line }) {
                    MarginMarkerLabel(kind: marker.kind, size: min(12, slotHeight * 0.28), isRightMargin: isRightMargin)
                        .position(x: x, y: (CGFloat(index) + 0.5) * slotHeight)
                }
            }
        }
        // Positions are absolute; keep them from being mirrored in the right-to-left pager.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func lineView(_ line: MushafLine, metrics: MushafPageMetrics, renderer: PageRenderer) -> some View {
        switch line.kind {
        case .surahHeader(let number):
            if surahs.indices.contains(number - 1) {
                SurahHeaderGlyph(
                    surah: surahs[number - 1],
                    name: surahs[number - 1].name(in: l10n.language),
                    fontSize: metrics.headerFontSize
                )
                .anchorPreference(key: MushafElementBoundsKey.self, value: .bounds) {
                    [MushafElementAnchor(element: .surahHeader(number), bounds: $0)]
                }
            }
        case .basmala:
            Text(verbatim: basmala)
                .font(faces.font(.ayahText, size: metrics.fontSize))
                .foregroundStyle(palette.text)
                .fixedSize()
                .anchorPreference(key: MushafElementBoundsKey.self, value: .bounds) {
                    [MushafElementAnchor(element: .basmala(line: line.number), bounds: $0)]
                }
        case .text:
            JustifiedLine(
                line: line,
                renderer: renderer,
                fontSize: metrics.fontSize,
                isCentered: metrics.centeredLines.contains(line.number),
                selectedAyah: selectedAyah,
                highlights: highlights,
                onSelect: onSelect
            )
        }
    }
}

/// Smallest fitted font size among the pages below; a spread draws both pages with it.
nonisolated struct MushafFontSizeKey: PreferenceKey {
    static let defaultValue: CGFloat = .infinity

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

extension EnvironmentValues {
    /// Upper bound for a page's font size (the shared size of a spread).
    @Entry var mushafFontSizeCap: CGFloat = .infinity
}
