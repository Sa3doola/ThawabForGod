//
//  PrayerTrackerRepository.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData-backed prayer tracking.
///
/// `@ModelActor`, like every other repository here: its own `ModelContext` on its own executor,
/// so a write happens off the main actor and never touches the context SwiftUI draws from. Only
/// `PrayerRecord` values cross the boundary.
@ModelActor
actor PrayerTrackerRepository: PrayerTrackerRepositoring {

    func record(on day: Date) throws -> PrayerRecord {
        try storedRecord(on: day)?.domainValue ?? PrayerRecord(day: day)
    }

    func records(from start: Date, to end: Date) throws -> [PrayerRecord] {
        let descriptor = FetchDescriptor<PrayerCompletionRecord>(
            predicate: #Predicate { $0.day >= start && $0.day <= end },
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainValue)
    }

    /// Writes, updates, or deletes.
    ///
    /// The delete is the part worth naming: a day with nothing marked is indistinguishable from a
    /// day with no row, so keeping an empty one would grow the store by a row for every day the
    /// user opened the sheet, tapped a circle and tapped it again.
    func save(_ record: PrayerRecord) throws {
        let existing = try storedRecord(on: record.day)

        switch (existing, record.completed.isEmpty) {
        case (let existing?, true):
            modelContext.delete(existing)
        case (let existing?, false):
            existing.apply(record)
        case (nil, false):
            modelContext.insert(PrayerCompletionRecord(record))
        case (nil, true):
            return // nothing stored, nothing to store
        }

        try modelContext.save()
    }

    /// `#Predicate` cannot close over a property of a struct, so the day is lifted into a local
    /// first — the same shape every other repository here needs.
    private func storedRecord(on day: Date) throws -> PrayerCompletionRecord? {
        let target = day

        var descriptor = FetchDescriptor<PrayerCompletionRecord>(
            predicate: #Predicate { $0.day == target }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
