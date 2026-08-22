//
//  HadithMemorizationRepository.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData-backed memorization schedules.
///
/// `@ModelActor` gives this actor its own `ModelContext` on its own executor, so a save happens
/// off the main actor and never touches the context SwiftUI draws from — the same shape
/// `HadithProgressRepository` uses. Only `HadithMemorization` values cross the boundary; no
/// `@Model` ever does.
@ModelActor
actor HadithMemorizationRepository: HadithMemorizationRepositoring {

    func all() throws -> [HadithMemorization] {
        let descriptor = FetchDescriptor<HadithMemorizationRecord>(
            sortBy: [SortDescriptor(\.dueOn)]
        )
        return try modelContext.fetch(descriptor).map(\.domainValue)
    }

    /// The due queue, as a predicate the store answers rather than a list this filters.
    ///
    /// `<=` rather than `==`: an item the reader missed on Tuesday is still due on Thursday, and
    /// a queue that only ever offered today's would quietly drop everything skipped. Soonest-due
    /// first, so the longest-overdue narration is the first one asked.
    func due(on date: Date) throws -> [HadithMemorization] {
        var descriptor = FetchDescriptor<HadithMemorizationRecord>(
            predicate: #Predicate { $0.dueOn <= date },
            sortBy: [SortDescriptor(\.dueOn)]
        )
        // A second key, so a queue of items all due the same day is in a stable order rather than
        // whatever the store happens to return — a review session that reshuffles under the
        // reader on every reload is disorienting for no reason.
        descriptor.sortBy.append(SortDescriptor(\.number))
        return try modelContext.fetch(descriptor).map(\.domainValue)
    }

    /// Starts memorizing, or leaves an existing schedule exactly as it is.
    ///
    /// Leaving it alone is the whole point: adding a narration the reader is three weeks into
    /// would otherwise reset it to a new item and throw that away.
    func add(_ memorization: HadithMemorization) throws {
        guard try record(for: memorization.id) == nil else { return }

        modelContext.insert(HadithMemorizationRecord(memorization))
        try modelContext.save()
    }

    func remove(_ id: HadithID) throws {
        guard let existing = try record(for: id) else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    /// Writes an answered card's new schedule onto the row it belongs to.
    ///
    /// A no-op when the narration is not being memorized — which happens if the reader stops
    /// memorizing something while its card is still on screen, and is not worth an error.
    func update(_ memorization: HadithMemorization) throws {
        guard let existing = try record(for: memorization.id) else { return }

        existing.apply(memorization.state)
        try modelContext.save()
    }

    /// `#Predicate` cannot close over a struct's properties, so the three parts are lifted into
    /// locals first — otherwise the macro tries to capture `id` itself and fails to build.
    private func record(for id: HadithID) throws -> HadithMemorizationRecord? {
        let collection = id.collection
        let number = id.number
        let part = id.part

        var descriptor = FetchDescriptor<HadithMemorizationRecord>(
            predicate: #Predicate {
                $0.collection == collection && $0.number == number && $0.part == part
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
