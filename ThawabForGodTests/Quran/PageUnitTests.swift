//
//  PageUnitTests.swift
//  ThawabForGodTests
//

import CoreGraphics
import Foundation
import Testing
@testable import ThawabForGod

/// Ported from Mushaf's `PageUnitTests` (Phase 6.1): the page-unit rules and readable text in
/// iPhone landscape. The fold-kind test is in `Layout/FoldGeometryTests`, and the settings-decoding
/// test is dropped: settings are separate keys now (`QuranReaderSettingsTests` covers fallbacks).
@MainActor
struct PageUnitTests {
    // Sizes in points: the reader's safe-area size.
    static let phonePortrait = CGSize(width: 402, height: 780)
    static let proMaxLandscape = CGSize(width: 832, height: 419)
    static let padLandscape = CGSize(width: 1376, height: 960)
    static let padPortrait = CGSize(width: 1032, height: 1300)
    static let duoInner = CGSize(width: 1000, height: 860)

    @Test func phonePortraitIsOnePage() {
        #expect(MushafPageUnit.resolve(size: Self.phonePortrait, isCompactWidth: true) == .single)
    }

    @Test func phoneLandscapeFitsTheWidthUnlessTwoPagesAreChosen() {
        // Pro Max landscape has a regular width and a compact height: the height decides.
        #expect(MushafPageUnit.resolve(size: Self.proMaxLandscape, isCompactHeight: true) == .widthFit)
        #expect(MushafPageUnit.resolve(size: Self.proMaxLandscape, isCompactWidth: true, isCompactHeight: true) == .widthFit)
        #expect(MushafPageUnit.resolve(size: Self.proMaxLandscape, isCompactHeight: true, phoneLandscape: .twoPages) == .spread)
        #expect(MushafPageUnit.widthFit.pageCount == 1)
    }

    @Test func iPadAndWideMacWindowsShowSpreads() {
        #expect(MushafPageUnit.resolve(size: Self.padLandscape) == .spread)
        #expect(MushafPageUnit.resolve(size: Self.padPortrait) == .single)
        #expect(MushafPageUnit.resolve(size: CGSize(width: 1200, height: 820)) == .spread, "Mac default window")
        #expect(MushafPageUnit.resolve(size: CGSize(width: 480, height: 600)) == .single, "Mac minimum window")
        // A compact-width split (Slide Over, 1/3) never gets a spread.
        #expect(MushafPageUnit.resolve(size: CGSize(width: 700, height: 500), isCompactWidth: true) == .single)
    }

    @Test func aVerticalFoldKeepsTheSpread() {
        #expect(MushafPageUnit.resolve(size: Self.duoInner, fold: .book) == .spread)
        #expect(MushafPageUnit.resolve(size: Self.duoInner, fold: .book, flatOpen: .singlePage) == .spread, "book pose ignores the flat setting")
        #expect(MushafPageUnit.resolve(size: Self.duoInner, fold: .flat) == .spread)
        #expect(MushafPageUnit.resolve(size: Self.duoInner, fold: .flat, flatOpen: .singlePage) == .single)
    }

    /// docs/06: landscape on the largest iPhone reads at 22 pt or more. The page is fitted to
    /// the safe-area width of a Pro Max in landscape (832 pt; the 6.7" models have 814), minus
    /// the page's side margins, with ~60 pt of header and footer. Measured 2026-10-08: 36.8 pt
    /// at 814 and 37.6 pt at 832 on pages 3, 50 and 187 (the slot height decides, not the width).
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason), arguments: [50, 187, 3], [814.0, 832.0])
    func landscapeTextIsReadable(_ number: Int, _ width: Double) async throws {
        let corpus = try await QuranTestData.repository(QuranTestData.fullDatabase).loadCorpus(style: .madaniV2)
        let page = try #require(corpus.page(number))
        let faces = QuranFaces.launch
        let store = FontPackStore()
        await store.ensureRegistered(around: number, style: corpus.style)
        let renderer = await PageRenderer.resolve(style: corpus.style, page: number, forced: nil, store: store)
        #expect(renderer == .glyph(fontName: String(format: "QCF2%03d", number)))
        let measurement = await PageMetricsCache().measurement(
            for: page, style: corpus.style.id, basmala: corpus.basmala, faces: faces, renderer: renderer
        )
        let pageSize = MushafUnitView.widthFittedPageSize(width: width, style: corpus.style)
        let content = CGSize(width: pageSize.width - 2 * MushafPageView.sideMargin, height: pageSize.height - 60)
        let metrics = MushafPageMetrics(
            page: page, measurement: measurement, size: content, slotCount: corpus.style.linesPerPage, renderer: renderer
        )
        #expect(metrics.fontSize >= 22, "page \(number) at \(width) pt")
    }
}

/// Ported from Mushaf's `TapZoneTests` (Phase 6.6): the iPhone's tap zones.
struct TapZoneTests {
    @Test func edgesTurnThePageLikeABook() {
        // The left edge is the next page: a Mushaf is read right to left.
        #expect(MushafTapZone.zone(x: 10, width: 400) == .nextPage)
        #expect(MushafTapZone.zone(x: 59, width: 400) == .nextPage)
        #expect(MushafTapZone.zone(x: 61, width: 400) == .middle)
        #expect(MushafTapZone.zone(x: 200, width: 400) == .middle)
        #expect(MushafTapZone.zone(x: 341, width: 400) == .previousPage)
        #expect(MushafTapZone.zone(x: 399, width: 400) == .previousPage)
        #expect(MushafTapZone.zone(x: 10, width: 0) == .middle)
    }

    @MainActor
    @Test func handlingTurnsOrToggles() {
        var turned: [MushafPageTurn] = []
        var toggles = 0
        let handling = MushafTapHandling(width: 400, turn: { turned.append($0) }, toggleChrome: { toggles += 1 })
        #expect(handling.turnsPage(at: CGPoint(x: 20, y: 300)))
        #expect(!handling.turnsPage(at: CGPoint(x: 200, y: 300)), "an ayah in the middle is selected")
        handling.tapOutsideText(at: CGPoint(x: 390, y: 10))
        handling.tapOutsideText(at: CGPoint(x: 200, y: 10))
        #expect(turned == [.next, .previous])
        #expect(toggles == 1)
    }
}
