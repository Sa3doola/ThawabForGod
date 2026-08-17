//
//  TasbihUseCase.swift
//  ThawabForGod
//

import Foundation

/// The counter's rules, and the seam between its two stores.
///
/// It is the only place that knows a tasbih is assembled from two halves — read-only phrases from
/// the corpus, a mutable count from SwiftData — which is what lets `TasbihViewModel` ask for "the
/// session for this dhikr" without caring that one of those came from a file it cannot write and
/// the other from a database it can.
///
/// The counting itself is `counting(_:now:)` below: static, pure, and taking no repository at all,
/// so the lap arithmetic can be tested exhaustively without a database in sight.
nonisolated struct TasbihUseCase: Sendable {
    private let catalog: any TasbihCatalogProviding
    private let progress: any TasbihProgressRepositoring
    private let now: @Sendable () -> Date

    init(
        catalog: any TasbihCatalogProviding,
        progress: any TasbihProgressRepositoring,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.catalog = catalog
        self.progress = progress
        self.now = now
    }

    // MARK: The catalog

    func presets(in language: AppLanguage) async throws -> [TasbihDhikr] {
        try await catalog.presets(in: language)
    }

    // MARK: A session

    /// The stored session for a preset, or a fresh one if it has never been counted.
    ///
    /// Never `nil`, unlike the repository call underneath it: "no row yet" and "zero so far" are
    /// the same thing to a screen, and making every caller collapse the optional itself would be
    /// the same three lines repeated.
    ///
    /// A stored session whose target no longer matches the preset is carried forward as stored.
    /// The corpus can be rebuilt with a different target, and someone who is 20 into a lap of 33
    /// should not be silently moved to 20 of 100 — the lap they are inside finishes under the
    /// rules it began with, and the next one picks up the new target.
    func session(for dhikr: TasbihDhikr) async throws -> TasbihSession {
        if let stored = try await progress.session(for: dhikr.id) {
            return stored
        }
        return TasbihSession.starting(dhikr, now: now())
    }

    func save(_ session: TasbihSession) async throws {
        try await progress.save(session)
    }

    /// Clears a preset's progress and hands back the empty session that replaces it.
    func reset(_ dhikr: TasbihDhikr) async throws -> TasbihSession {
        try await progress.reset(dhikrID: dhikr.id)
        return TasbihSession.starting(dhikr, now: now())
    }

    // MARK: Counting

    /// What one recitation did.
    struct CountOutcome: Equatable, Sendable {
        let session: TasbihSession

        /// Whether that recitation was the one that finished a lap. The view model persists on
        /// this and the screen sounds a different haptic for it, so it is reported rather than
        /// left to be re-derived by comparing two sessions.
        let completedLap: Bool
    }

    /// Records one recitation.
    ///
    /// Pure and `static`: no repository, no clock beyond what is passed in, no isolation. Every
    /// interesting question about this feature — does 33 wrap, does the lap counter move, does a
    /// count survive a target that changed underneath it — is a question about this function, and
    /// it can be asked without building anything.
    ///
    /// The wrap is immediate: the 33rd recitation of a 33-lap does not sit on screen as 33 of 33,
    /// it completes the lap and the count returns to zero. That is how a physical misbaha behaves
    /// — the bead you finish on is the first of the next round — and it is why `totalCount`
    /// exists for anything that needs a number that only goes up.
    static func counting(_ session: TasbihSession, now: Date = Date()) -> CountOutcome {
        var counted = session
        counted.currentCount += 1
        counted.lastUpdated = now

        // `>=` rather than `==`: a session restored with a count already past its target — a
        // corpus rebuild that lowered it — must still be able to close the lap it is inside
        // instead of counting upwards forever.
        let completedLap = counted.currentCount >= counted.targetCount

        if completedLap {
            counted.completedLaps += 1
            counted.currentCount = 0
        }

        return CountOutcome(session: counted, completedLap: completedLap)
    }
}
