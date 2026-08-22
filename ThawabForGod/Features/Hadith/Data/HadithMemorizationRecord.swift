//
//  HadithMemorizationRecord.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData's representation of a `HadithMemorization`. Stays inside `Data`, as every `@Model` in
/// this project does: an instance is bound to the context that fetched it and must never cross an
/// actor boundary — the domain value type is what travels.
///
/// `MemorizationState` is stored as its five fields rather than as an embedded value, because
/// `dueOn` has to be something the store can sort and filter on. The whole point of the due queue
/// is that it is a predicate the database answers, not a list the app fetches and sifts.
///
/// **Uniqueness is the repository's job, not the schema's** — the same position
/// `HadithBookmarkRecord` is in, and for the same reason: what has to be unique is the triple,
/// and `#Unique` over several properties is iOS 18 where this app targets 17.
///
/// Every property carries a default, which SwiftData needs for lightweight migration to add this
/// model to a store that already exists.
@Model
nonisolated final class HadithMemorizationRecord {
    var collection: String = ""
    var number: Int = 0
    var part: Int = 0
    var bookNumber: Int = 0

    var easiness: Double = MemorizationState.initialEasiness
    var repetition: Int = 0
    var intervalInDays: Int = 0
    var dueOn: Date = Date()
    var lastReviewedOn: Date?

    init(
        collection: String,
        number: Int,
        part: Int,
        bookNumber: Int,
        easiness: Double,
        repetition: Int,
        intervalInDays: Int,
        dueOn: Date,
        lastReviewedOn: Date?
    ) {
        self.collection = collection
        self.number = number
        self.part = part
        self.bookNumber = bookNumber
        self.easiness = easiness
        self.repetition = repetition
        self.intervalInDays = intervalInDays
        self.dueOn = dueOn
        self.lastReviewedOn = lastReviewedOn
    }

    convenience init(_ memorization: HadithMemorization) {
        self.init(
            collection: memorization.id.collection,
            number: memorization.id.number,
            part: memorization.id.part,
            bookNumber: memorization.bookNumber,
            easiness: memorization.state.easiness,
            repetition: memorization.state.repetition,
            intervalInDays: memorization.state.intervalInDays,
            dueOn: memorization.state.dueOn,
            lastReviewedOn: memorization.state.lastReviewedOn
        )
    }

    /// Overwrites this row with a new schedule. Used by `update`, which replaces rather than
    /// deleting and re-inserting so the row's identity in the store stays put.
    func apply(_ state: MemorizationState) {
        easiness = state.easiness
        repetition = state.repetition
        intervalInDays = state.intervalInDays
        dueOn = state.dueOn
        lastReviewedOn = state.lastReviewedOn
    }

    var domainValue: HadithMemorization {
        HadithMemorization(
            id: HadithID(collection: collection, number: number, part: part),
            bookNumber: bookNumber,
            state: MemorizationState(
                easiness: easiness,
                repetition: repetition,
                intervalInDays: intervalInDays,
                dueOn: dueOn,
                lastReviewedOn: lastReviewedOn
            )
        )
    }
}
