//
//  ReviewGrade.swift
//  ThawabForGod
//

import Foundation

/// How well the reader recalled an item, as the four answers a screen can offer.
///
/// SM-2 is specified over a six-point scale, 0 to 5, which is more precision than anyone can
/// report about their own recall. Four buttons is the shape every practical implementation
/// converges on, and this enum is that shape with the scale it maps onto written down beside it
/// rather than left implicit in the scheduler.
nonisolated enum ReviewGrade: String, CaseIterable, Hashable, Sendable {

    /// Did not recall it. Resets the item — see `SpacedRepetitionScheduler`.
    case again

    /// Recalled it, but with difficulty. Correct, and the item gets harder from here.
    case hard

    /// Recalled it. The ordinary answer, and the one that leaves the item's difficulty alone.
    case good

    /// Recalled it immediately. The item gets easier, and its intervals grow faster.
    case easy

    /// The SM-2 quality score this answer stands for.
    ///
    /// The algorithm's own boundary is at 3: below it the item is treated as failed and its
    /// repetition count goes back to zero. `hard` sits exactly on that boundary — it is a *pass*,
    /// which is why it is 3 rather than 2, and why answering "hard" does not throw away the
    /// reader's progress on an item they did in fact remember.
    var quality: Int {
        switch self {
        case .again: 0
        case .hard: 3
        case .good: 4
        case .easy: 5
        }
    }

    /// Whether the item was recalled at all. The one distinction the scheduler branches on.
    var isRecalled: Bool { quality >= 3 }
}
