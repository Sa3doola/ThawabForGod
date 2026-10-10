//
//  PageMetricsCache.swift
//  ThawabForGod
//

import Foundation
import os

/// Page measurements (`PageMeasurement`) for the session, measured off the main actor.
///
/// Ported from Mushaf with its isolation exactly as it was (T13). The actor measures and merges
/// concurrent requests for the same page. Finished results are also kept in a lock-protected store
/// that views read synchronously, so a page measured before — paging back, the neighbour of a
/// spread — draws in its first frame.
///
/// Keyed by style, page, the faces in use and the renderer, **not by view size**: widths are
/// measured at a reference size and scaled per size by `MushafPageMetrics`.
///
/// One instance per app, owned by `AppContainer` rather than Mushaf's `static let shared`, so tests
/// and previews get a cache of their own.
actor PageMetricsCache {
    nonisolated struct Key: Hashable, Sendable {
        let style: MushafStyleID
        let page: Int
        let faces: Set<QuranFace>
        let renderer: PageRenderer

        init(style: MushafStyleID, page: Int, faces: QuranFaces, renderer: PageRenderer = .unicode) {
            self.style = style
            self.page = page
            self.faces = faces.available
            self.renderer = renderer
        }
    }

    /// Read synchronously by views; written only by this actor. Invariant: nothing suspends inside
    /// `withLock`.
    private nonisolated let finished = OSAllocatedUnfairLock<[Key: PageMeasurement]>(initialState: [:])
    private var inFlight: [Key: Task<PageMeasurement, Never>] = [:]

    init() {}

    /// The measurement if it is ready. Never measures, so it is safe on the main actor.
    nonisolated func cached(_ key: Key) -> PageMeasurement? {
        finished.withLock { $0[key] }
    }

    /// The page's measurement, measuring it off the main actor on first request.
    func measurement(
        for page: MushafPage, style: MushafStyleID, basmala: String, faces: QuranFaces, renderer: PageRenderer = .unicode
    ) async -> PageMeasurement {
        let key = Key(style: style, page: page.number, faces: faces, renderer: renderer)
        if let ready = cached(key) { return ready }
        if let running = inFlight[key] { return await running.value }
        // Detached, not a child of this actor's task: thousands of CoreText calls must not hold the
        // actor (and every other page's request behind it) for the length of one page, and must
        // never inherit a main-actor caller's isolation.
        let task = Task.detached(priority: .userInitiated) {
            PageMeasurement(page: page, basmala: basmala, faces: faces, renderer: renderer)
        }
        inFlight[key] = task
        let measurement = await task.value
        finished.withLock { $0[key] = measurement }
        inFlight[key] = nil
        return measurement
    }

    /// Number of measured pages, for tests and the performance probe.
    nonisolated var count: Int { finished.withLock { $0.count } }
}
