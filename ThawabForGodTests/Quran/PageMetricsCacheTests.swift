//
//  PageMetricsCacheTests.swift
//  ThawabForGodTests
//

import CoreGraphics
import Foundation
import Testing
@testable import ThawabForGod

/// Ported from Mushaf's `PageMetricsCacheTests` (Phase 1.6): page measurements are made off the
/// main actor, once, and reused. Serialised because the page faces are process-wide.
@Suite(.serialized) @MainActor
struct PageMetricsCacheTests {
    let faces = QuranFaces.launch

    private func page(_ number: Int) async throws -> (MushafPage, String) {
        let corpus = try await QuranTestData.repository(QuranTestData.fullDatabase).loadCorpus(style: .madaniV2)
        return (try #require(corpus.page(number)), corpus.basmala)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func measuresOnceAndServesFromTheSynchronousStore() async throws {
        let cache = PageMetricsCache()
        let (page, basmala) = try await page(50)
        let key = PageMetricsCache.Key(style: .madaniV2, page: 50, faces: faces)
        #expect(cache.cached(key) == nil)

        // Called from the main actor; TextMeasurer's DEBUG precondition would stop the
        // test if the measuring ran here.
        let measured = await cache.measurement(for: page, style: .madaniV2, basmala: basmala, faces: faces)
        #expect(cache.cached(key) == measured)
        #expect(cache.count == 1)

        let again = await cache.measurement(for: page, style: .madaniV2, basmala: basmala, faces: faces)
        #expect(again == measured)
        #expect(cache.count == 1)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func concurrentRequestsShareOneMeasurement() async throws {
        let cache = PageMetricsCache()
        let (page, basmala) = try await page(3)
        async let a = cache.measurement(for: page, style: .madaniV2, basmala: basmala, faces: faces)
        async let b = cache.measurement(for: page, style: .madaniV2, basmala: basmala, faces: faces)
        let (first, second) = await (a, b)
        #expect(first == second)
        #expect(cache.count == 1)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func measurementCoversTextAndBasmalaLines() async throws {
        let (page, basmala) = try await page(50)
        let measurement = await PageMetricsCache().measurement(for: page, style: .madaniV2, basmala: basmala, faces: faces)
        let measuredLines = page.lines.filter { $0.kind != .surahHeader(3) }.map(\.number)
        #expect(Set(measurement.lineWidths.keys) == Set(measuredLines))
        #expect(measurement.lineWidths.values.allSatisfy { $0 > 0 })
    }

    @Test func fontsAreTheKeyNotTheViewSize() {
        let all = PageMetricsCache.Key(style: .madaniV2, page: 1, faces: faces)
        let fallback = PageMetricsCache.Key(style: .madaniV2, page: 1, faces: .unavailable)
        #expect(all != fallback)
    }

    @Test func metricsScaleTheMeasuredWidths() {
        // Two text lines measured at the 100 pt reference size. The page is tall enough that
        // the widest line (1000), not the slot height, sets the size.
        let lines = [
            MushafLine(number: 1, kind: .text, segments: [], isCentered: false),
            MushafLine(number: 2, kind: .text, segments: [], isCentered: false),
        ]
        let page = MushafPage(number: 9, juz: 1, lines: lines)
        let measurement = PageMeasurement(lineWidths: [1: 1000, 2: 300])
        let metrics = MushafPageMetrics(page: page, measurement: measurement, size: CGSize(width: 400, height: 1500), slotCount: 15)
        #expect(abs(metrics.fittedFontSize - 400 * 0.99 / 1000 * 100) < 0.001)
        #expect(metrics.slotHeight == 100)
        // Line 2 is 300/1000 of the widest, under the centering threshold.
        #expect(metrics.centeredLines == [2])
        let capped = MushafPageMetrics(page: page, measurement: measurement, size: CGSize(width: 400, height: 1500), slotCount: 15, fontSizeCap: 20)
        #expect(capped.fontSize == 20 && capped.fittedFontSize == metrics.fittedFontSize)
    }
}
