//
//  MemorizationState.swift
//  ThawabForGod
//

import Foundation

/// Where one item stands in its review schedule.
///
/// The whole of what SM-2 remembers about an item, and deliberately nothing about *which* item —
/// this type is as useful for a dhikr or a divine name as it is for a narration, which is why it
/// is in `Core` rather than in the feature that first needed it. What is being memorized is the
/// caller's business; how often to show it is this one's.
///
/// A value type with no identity: the feature's own record pairs it with whatever it is the state
/// *of*. That is what keeps the scheduler a pure function of a state and a grade.
nonisolated struct MemorizationState: Hashable, Sendable {

    /// SM-2's easiness factor — how fast this item's intervals grow.
    ///
    /// Starts at 2.5 and moves with every answer. **Never below 1.3**, which is the algorithm's
    /// own floor and not an arbitrary one: an item whose factor is allowed to collapse ends up
    /// scheduled every day forever, which in practice means the reader abandons the whole deck
    /// rather than the one item.
    let easiness: Double

    /// How many times in a row it has been recalled. Zero for a new item, and zero again after
    /// any answer of `.again` — which is what makes a lapse start the ladder over.
    let repetition: Int

    /// How many days until it is next due, from the day it was last reviewed.
    let intervalInDays: Int

    /// The day it is next due. Compared against today's date, never against `Date()` directly.
    let dueOn: Date

    /// When it was last answered, or `nil` for an item that has never been reviewed.
    let lastReviewedOn: Date?

    /// SM-2's starting easiness, and the value every new item begins at.
    static let initialEasiness = 2.5

    /// The floor the algorithm imposes on `easiness`.
    static let minimumEasiness = 1.3

    /// A new item, due immediately.
    ///
    /// Due *today* rather than tomorrow, because the reader has just chosen to memorize it and
    /// the one moment they certainly want to see it is now. Nothing in SM-2 says otherwise — the
    /// algorithm describes what happens after the first review, not before it.
    static func new(on date: Date) -> MemorizationState {
        MemorizationState(
            easiness: initialEasiness,
            repetition: 0,
            intervalInDays: 0,
            dueOn: date,
            lastReviewedOn: nil
        )
    }

    /// Whether this item is due on `date` — meaning due then *or before*, since an item the
    /// reader missed on Tuesday is still due on Thursday.
    func isDue(on date: Date) -> Bool { dueOn <= date }

    /// Whether the reader has ever answered this item.
    var isNew: Bool { lastReviewedOn == nil }
}
