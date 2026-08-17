//
//  TasbihSession.swift
//  ThawabForGod
//

import Foundation

/// How far through a dhikr someone is — the one part of this feature that is *theirs*.
///
/// This is the mutable half of the split the app draws down the middle of its storage: the phrase
/// and its target come out of the read-only corpus, and this comes out of SwiftData. A value type
/// with no tie to the context it was fetched from, so it crosses off the model actor freely.
///
/// The counting rules live in `TasbihUseCase` rather than here. That is deliberate — it keeps
/// this a record of *what is true now* and puts the question of what a tap does somewhere it can
/// be tested without a store.
nonisolated struct TasbihSession: Identifiable, Hashable, Sendable {

    /// The stored row's own identity. Not what a session is looked up by — `dhikrID` is.
    let id: UUID

    /// Which preset this is progress through. Unique in the store: one running session per dhikr,
    /// which is what makes `session(for:)` a lookup rather than a query returning a list.
    let dhikrID: TasbihDhikr.ID

    /// Recitations since the last completed lap, always in `0..<targetCount`.
    var currentCount: Int

    /// Copied from the dhikr at the time of counting rather than read live.
    ///
    /// A preset's target could change in a corpus rebuild, and a lap someone completed under the
    /// old one was still a completed lap. Storing it keeps the history honest and stops a data
    /// change from retroactively invalidating a count.
    var targetCount: Int

    /// How many full laps have been finished.
    var completedLaps: Int

    /// When the count last moved. What a "resume where you left off" prompt, or a daily reset,
    /// would eventually be built on.
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        dhikrID: TasbihDhikr.ID,
        currentCount: Int = 0,
        targetCount: Int,
        completedLaps: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.dhikrID = dhikrID
        self.currentCount = currentCount
        self.targetCount = max(1, targetCount)
        self.completedLaps = completedLaps
        self.lastUpdated = lastUpdated
    }

    /// A fresh session for a preset, for the first time someone opens it.
    static func starting(_ dhikr: TasbihDhikr, now: Date = Date()) -> TasbihSession {
        TasbihSession(dhikrID: dhikr.id, targetCount: dhikr.targetCount, lastUpdated: now)
    }

    /// Total recitations, laps included. Monotonic across a lap boundary, unlike `currentCount`,
    /// which is what makes it the right trigger for one haptic per tap.
    var totalCount: Int {
        completedLaps * targetCount + currentCount
    }
}
