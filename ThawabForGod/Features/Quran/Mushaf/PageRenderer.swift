//
//  PageRenderer.swift
//  ThawabForGod
//

import SwiftUI

/// The renderer one Mushaf page is actually drawn with: the style's choice, unless the page's font
/// is unavailable or a DEBUG launch option forces one.
///
/// Ported from Mushaf. **The Unicode path is a fallback, not a mode**: a page whose V2 font is
/// missing or mislabelled is still drawn — in KFGQPC Hafs, from the same words — rather than not
/// at all. In a public clone every page would be, which is one reason that build hides Mushaf mode.
nonisolated enum PageRenderer: Hashable, Sendable {
    /// Every word and ayah marker is a `glyph_v2` code in the page's own font, registered under
    /// this PostScript name ("QCF2050").
    case glyph(fontName: String)
    /// Hafs Unicode text in `QuranFace.ayahText`; the font draws the ayah-end markers too.
    case unicode

    /// The renderer for `page` given its font's status, or `nil` while the font is still pending:
    /// the page then waits for its font instead of flashing the Unicode text first.
    static func select(style: MushafStyle, page: Int, forced: RendererKind?, status: PageFontStatus) -> PageRenderer? {
        guard (forced ?? style.renderer) == .glyphPerPage, let pack = style.pageFonts else { return .unicode }
        switch status {
        case .registered: return .glyph(fontName: pack.postScriptName(page: page))
        case .unavailable: return .unicode
        case .pending: return nil
        }
    }

    /// The renderer for `page`, registering its font first if the pager has not yet.
    static func resolve(style: MushafStyle, page: Int, forced: RendererKind?, store: any FontPackStoring) async -> PageRenderer {
        if let renderer = select(style: style, page: page, forced: forced, status: store.status(page: page, style: style.id)) {
            return renderer
        }
        await store.ensureRegistered(page: page, style: style)
        // Still pending only if the style has no such page; draw Unicode rather than nothing.
        return select(style: style, page: page, forced: forced, status: store.status(page: page, style: style.id)) ?? .unicode
    }

    /// Spacing and line height of this renderer, in em of its font.
    var metrics: RendererMetrics {
        switch self {
        case .glyph: .glyphPerPage
        case .unicode: .unicode
        }
    }
}

/// Per-renderer layout constants, measured over all 604 pages in Mushaf's Phase 2.4: every page
/// laid out as `MushafPageContent` does, rendered, and checked for ink touching between
/// neighbouring words and lines.
nonisolated struct RendererMetrics: Sendable, Equatable {
    /// Minimum gap between words, in em. Justified lines spread wider; this sets the font size
    /// through the widest line.
    let minimumGapEm: CGFloat
    /// Slot height in em: the line pitch when the page height, not its width, sets the size.
    let slotHeightEm: CGFloat

    /// KFGQPC Hafs: about one space between words (from 0.2 em the only touching word pairs are
    /// fixed swashes). At 1.6 em, 5 line pairs touched; from 1.7 em none do.
    static let unicode = RendererMetrics(minimumGapEm: 0.22, slotHeightEm: 1.7)
    /// QPC V2: the glyphs already fill the line (full lines differ by about 2%), so the gap stays
    /// small: justified gaps come out at 0.13 em (median), and 14 of 74,848 word pairs touch, as
    /// designed swashes. 1.85 em (QUL's preview pitch) left 2 touching line pairs, among them page
    /// 187's first line against the At-Tawbah header; from 2.0 em none do.
    static let glyphPerPage = RendererMetrics(minimumGapEm: 0.1, slotHeightEm: 2.0)
}

extension EnvironmentValues {
    /// A renderer every page is drawn with when its font allows — the DEBUG launch option that
    /// compares the two side by side. `nil` (the style's own) everywhere else.
    @Entry var forcedRenderer: RendererKind? = nil
}
