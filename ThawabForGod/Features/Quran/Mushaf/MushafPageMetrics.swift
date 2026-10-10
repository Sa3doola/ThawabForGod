//
//  MushafPageMetrics.swift
//  ThawabForGod
//

import CoreGraphics

/// The expensive part of laying out a page: each line's natural width, measured with the real
/// fonts at a reference size.
///
/// Independent of the view size, so it is measured once per page — off the main actor, by
/// `PageMetricsCache` — and scaled from there by `MushafPageMetrics`, which is plain arithmetic.
/// Ported from Mushaf unchanged (T13).
nonisolated struct PageMeasurement: Sendable, Equatable {
    static let referenceSize: CGFloat = 100

    /// Natural width at `referenceSize` of every text and basmala line, by line number.
    let lineWidths: [Int: CGFloat]

    init(lineWidths: [Int: CGFloat]) {
        self.lineWidths = lineWidths
    }

    /// Measures every word and marker with CoreText, as `renderer` draws them. **Never call this on
    /// the main actor** — `TextMeasurer` stops a DEBUG build that does.
    init(page: MushafPage, basmala: String, faces: QuranFaces, renderer: PageRenderer = .unicode) {
        let reference = Self.referenceSize
        let text = faces.platformFont(.ayahText, size: reference)
        let gap = reference * renderer.metrics.minimumGapEm

        // The font the items are drawn in; a page font is registered and checked by the page-font
        // store before the glyph renderer is ever chosen.
        let itemFont: PlatformFont
        switch renderer {
        case .glyph(let fontName): itemFont = TextMeasurer.font(named: fontName, size: reference) ?? text
        case .unicode: itemFont = text
        }

        func naturalWidth(_ line: MushafLine) -> CGFloat {
            let items = LineItem.items(for: line, renderer: renderer)
            let width = items.reduce(0) { $0 + TextMeasurer.width(of: $1.text, font: itemFont) }
            return width + CGFloat(max(0, items.count - 1)) * gap
        }

        var widths: [Int: CGFloat] = [:]
        for line in page.lines {
            switch line.kind {
            case .text: widths[line.number] = naturalWidth(line)
            case .basmala: widths[line.number] = TextMeasurer.width(of: basmala, font: text)
            case .surahHeader: break
            }
        }
        lineWidths = widths
    }
}

/// Font size and line treatment for one Mushaf page at a given size.
///
/// The page is the unit: the font is chosen so the widest line still fits the width and one line
/// fits one slot. Widths come from `PageMeasurement` — measured with the real fonts, never
/// estimated — and this type only scales them, so it is cheap on the main actor.
nonisolated struct MushafPageMetrics: Equatable {
    /// Lines narrower than this share of the width are centred instead of justified.
    static let centeringThreshold: CGFloat = 0.7
    /// QCF_SurahHeader_COLOR: every header glyph is 3.30 em wide (pipeline test) and its ink is
    /// 0.42 em tall, centred on the baseline.
    static let headerAdvanceEm: CGFloat = 3.30
    static let headerHeightEm: CGFloat = 0.42
    /// Share of the slot height a header may fill.
    static let headerSlotFill: CGFloat = 0.95

    /// Size used for drawing: the fitted size, or a smaller shared one (spreads).
    let fontSize: CGFloat
    /// Largest size this page alone could use.
    let fittedFontSize: CGFloat
    let slotHeight: CGFloat
    /// Size of the surah header glyph: as wide as the text block, unless the slot is too low.
    let headerFontSize: CGFloat
    /// Line numbers drawn centred with natural spacing.
    let centeredLines: Set<Int>

    /// - Parameter slotCount: line slots on a full page (`MushafStyle.linesPerPage`); short pages
    ///   use the same slot height.
    init(
        page: MushafPage, measurement: PageMeasurement, size: CGSize, slotCount: Int, fontSizeCap: CGFloat = .infinity,
        renderer: PageRenderer = .unicode
    ) {
        let reference = PageMeasurement.referenceSize
        let widths = measurement.lineWidths

        slotHeight = size.height / CGFloat(slotCount)
        headerFontSize = min(size.width * 0.99 / Self.headerAdvanceEm, slotHeight * Self.headerSlotFill / Self.headerHeightEm)
        // 1% safety margin for rounding between CoreText measurement and SwiftUI layout.
        let available = size.width * 0.99
        let widest = widths.values.max() ?? reference
        let byWidth = available / widest * reference
        let byHeight = slotHeight / renderer.metrics.slotHeightEm
        fittedFontSize = max(8, min(byWidth, byHeight))
        let fontSize = min(fittedFontSize, fontSizeCap)
        self.fontSize = fontSize

        centeredLines = Set(page.lines.compactMap { line in
            guard line.kind == .text, let width = widths[line.number] else { return nil }
            let scaled = width / reference * fontSize
            return line.isCentered || scaled < size.width * Self.centeringThreshold ? line.number : nil
        })
    }
}
