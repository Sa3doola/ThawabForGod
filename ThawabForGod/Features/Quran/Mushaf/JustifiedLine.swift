//
//  JustifiedLine.swift
//  ThawabForGod
//

import SwiftUI

/// One Mushaf text line: every word and every ayah marker is its own subview, laid out
/// right-to-left and justified to the full width — a single `Text` cannot justify.
///
/// Ported from Mushaf. The ayah context menu arrives with the ayah actions (M5).
struct JustifiedLine: View {
    let line: MushafLine
    let renderer: PageRenderer
    let fontSize: CGFloat
    let isCentered: Bool
    let selectedAyah: VerseReference?
    /// The reader's highlight colours for ayahs on this line, drawn as bands like the selection.
    var highlights: [VerseReference: HighlightColor] = [:]
    let onSelect: (VerseReference) -> Void

    @Environment(\.quranFaces) private var faces
    @Environment(\.readingPalette) private var palette
    /// iPhone immersive reading: a tap in the page's edge zones turns the page instead.
    @Environment(\.mushafTapHandling) private var tapHandling

    var body: some View {
        JustifiedLineLayout(justify: !isCentered, minimumSpacing: fontSize * renderer.metrics.minimumGapEm) {
            ForEach(LineItem.items(for: line, renderer: renderer)) { item in
                // A tap, not a Button, so its position can be checked against the edge zones.
                // VoiceOver reads and activates the page's per-ayah elements, never these.
                label(for: item)
                    .anchorPreference(key: HighlightBoundsKey.self, value: .bounds) {
                        item.ayah == selectedAyah || highlights[item.ayah] != nil ? [item.ayah: [$0]] : [:]
                    }
                    .anchorPreference(key: MushafElementBoundsKey.self, value: .bounds) {
                        [MushafElementAnchor(element: .ayah(item.ayah), bounds: $0)]
                    }
                    .anchorPreference(key: LineItemBoundsKey.self, value: .bounds) {
                        [LineItemBounds(ayah: item.ayah, bounds: $0)]
                    }
                    .contentShape(.rect)
                    .onTapGesture(coordinateSpace: .named(MushafTapHandling.space)) { location in
                        if tapHandling?.turnsPage(at: location) == true { return }
                        onSelect(item.ayah)
                    }
            }
        }
        // An ayah's words on a line are contiguous: one band behind them, extended into the gaps,
        // instead of a box per word. The reader's highlight first, the selection over it.
        .backgroundPreferenceValue(HighlightBoundsKey.self) { anchors in
            GeometryReader { proxy in
                ForEach(anchors.keys.sorted(), id: \.self) { ayah in
                    if let band = anchors[ayah]?.map({ proxy[$0] }).reduce(nil, { $0?.union($1) ?? $1 }) {
                        ZStack {
                            if let color = highlights[ayah] {
                                bandShape.fill(palette.highlight(color))
                            }
                            if ayah == selectedAyah {
                                bandShape.fill(palette.selection)
                            }
                        }
                        .frame(width: band.width + fontSize * 0.3, height: band.height)
                        .position(x: band.midX, y: band.midY)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        // A tap between two items (the gaps are the only whitespace on a justified line, and narrow
        // with the glyph renderer) selects the ayah of the nearest item.
        .backgroundPreferenceValue(LineItemBoundsKey.self) { items in
            GeometryReader { proxy in
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { location in
                        let frames = items.map { ($0.ayah, proxy[$0.bounds]) }
                        if let tapHandling {
                            // The same point in the page unit, for the edge zones.
                            let line = proxy.frame(in: .named(MushafTapHandling.space))
                            if tapHandling.turnsPage(at: CGPoint(x: line.minX + location.x, y: line.minY + location.y)) { return }
                        }
                        if let ayah = LineItemBounds.nearest(to: location.x, in: frames) { onSelect(ayah) }
                    }
            }
        }
        // The layout places items right-to-left in absolute coordinates; pin the direction so
        // SwiftUI does not mirror that placement a second time inside the right-to-left pager.
        .environment(\.layoutDirection, .leftToRight)
    }

    private var bandShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: fontSize * 0.25)
    }

    private func label(for item: LineItem) -> some View {
        Text(verbatim: item.text)
            .font(font)
            .foregroundStyle(palette.text)
            .fixedSize()
    }

    /// The page font for glyph codes. `PageRenderer.glyph` is only chosen once its font registered
    /// and resolved to this name (`FontPackStore`), so `Font.custom` cannot fall back silently.
    private var font: Font {
        switch renderer {
        case .glyph(let fontName): .custom(fontName, fixedSize: fontSize)
        case .unicode: faces.font(.ayahText, size: fontSize)
        }
    }
}

/// Bounds of one item on a line, with the ayah it belongs to.
nonisolated struct LineItemBounds {
    let ayah: VerseReference
    let bounds: Anchor<CGRect>

    /// The ayah of the item horizontally nearest to `x` (inside it counts as distance 0).
    static func nearest(to x: CGFloat, in frames: [(VerseReference, CGRect)]) -> VerseReference? {
        frames.min { distance(x, $0.1) < distance(x, $1.1) }?.0
    }

    private static func distance(_ x: CGFloat, _ frame: CGRect) -> CGFloat {
        x < frame.minX ? frame.minX - x : max(0, x - frame.maxX)
    }
}

nonisolated struct LineItemBoundsKey: PreferenceKey {
    static let defaultValue: [LineItemBounds] = []

    static func reduce(value: inout [LineItemBounds], nextValue: () -> [LineItemBounds]) {
        value.append(contentsOf: nextValue())
    }
}

/// Bounds of the items of the selected and the highlighted ayahs on one line, by ayah.
nonisolated struct HighlightBoundsKey: PreferenceKey {
    static let defaultValue: [VerseReference: [Anchor<CGRect>]] = [:]

    static func reduce(value: inout [VerseReference: [Anchor<CGRect>]], nextValue: () -> [VerseReference: [Anchor<CGRect>]]) {
        value.merge(nextValue()) { $0 + $1 }
    }
}

/// A word or an ayah marker on a line.
nonisolated struct LineItem: Identifiable, Hashable {
    /// Position on the line, in reading order.
    let id: Int
    let ayah: VerseReference
    /// What to draw in the renderer's font: a glyph code (`.glyph`) or Hafs text (`.unicode`).
    /// Either font draws the ayah-end marker itself, from the marker's own text.
    let text: String

    /// The line's items in reading order. The end marker is drawn as one more "word"; it still
    /// belongs to (and selects) the ayah it ends.
    static func items(for line: MushafLine, renderer: PageRenderer = .unicode) -> [LineItem] {
        var items: [LineItem] = []
        for segment in line.segments {
            let words: [String]
            let marker: String?
            switch renderer {
            case .glyph:
                words = segment.glyphs
                marker = segment.markerGlyph
            case .unicode:
                words = segment.words
                marker = segment.markerText
            }
            for word in words {
                items.append(LineItem(id: items.count, ayah: segment.reference, text: word))
            }
            if segment.endsAyah, let marker {
                items.append(LineItem(id: items.count, ayah: segment.reference, text: marker))
            }
        }
        return items
    }
}

/// Places subviews from the right edge leftwards on a shared baseline. When justifying, the
/// leftover width is split equally between the gaps; otherwise the row is centred with the minimum
/// spacing.
nonisolated struct JustifiedLineLayout: Layout {
    var justify: Bool
    var minimumSpacing: CGFloat

    struct Cache {
        var sizes: [CGSize]
        var baselines: [CGFloat]
    }

    func makeCache(subviews: Subviews) -> Cache {
        var cache = Cache(sizes: [], baselines: [])
        updateCache(&cache, subviews: subviews)
        return cache
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        cache.baselines = subviews.enumerated().map { index, subview in
            let baseline = subview.dimensions(in: .unspecified)[.firstTextBaseline]
            return baseline.isFinite ? baseline : cache.sizes[index].height
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let natural = naturalWidth(cache)
        let (above, below) = extents(cache)
        return CGSize(width: proposal.width ?? natural, height: above + below)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard !subviews.isEmpty else { return }
        let contentWidth = cache.sizes.reduce(0) { $0 + $1.width }
        let gaps = CGFloat(subviews.count - 1)

        var spacing = minimumSpacing
        var x = bounds.maxX
        if justify, gaps > 0 {
            spacing = max(0, (bounds.width - contentWidth) / gaps)
        } else {
            x = bounds.midX + (contentWidth + gaps * spacing) / 2
        }

        let (above, below) = extents(cache)
        let baselineY = bounds.midY - (above + below) / 2 + above
        for (index, subview) in subviews.enumerated() {
            let size = cache.sizes[index]
            x -= size.width
            subview.place(
                at: CGPoint(x: x, y: baselineY - cache.baselines[index]),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x -= spacing
        }
    }

    private func naturalWidth(_ cache: Cache) -> CGFloat {
        cache.sizes.reduce(0) { $0 + $1.width } + CGFloat(max(0, cache.sizes.count - 1)) * minimumSpacing
    }

    /// Largest distance above and below the shared baseline.
    private func extents(_ cache: Cache) -> (above: CGFloat, below: CGFloat) {
        var above: CGFloat = 0
        var below: CGFloat = 0
        for (size, baseline) in zip(cache.sizes, cache.baselines) {
            above = max(above, baseline)
            below = max(below, size.height - baseline)
        }
        return (above, below)
    }
}
