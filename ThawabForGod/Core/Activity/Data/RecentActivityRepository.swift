//
//  RecentActivityRepository.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData-backed recent activity.
///
/// `@ModelActor` gives this actor its own `ModelContext` on its own executor, so a write happens
/// off the main actor and never touches the context SwiftUI draws from — the same shape
/// `QuranProgressRepository` and `TasbihProgressRepository` use. Only `RecentActivity` values
/// cross the boundary; no `@Model` ever does.
@ModelActor
actor RecentActivityRepository: RecentActivityRepositoring {

    func recent() throws -> [RecentActivity] {
        let descriptor = FetchDescriptor<RecentActivityRecord>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        // `compactMap`, not `map`: a row whose kind this build no longer knows is dropped rather
        // than failing the fetch for the two that are fine.
        return try modelContext.fetch(descriptor).compactMap(\.domainValue)
    }

    /// Replaces this kind's row, or writes the first one.
    func record(_ activity: RecentActivity) throws {
        if let existing = try record(for: activity.kind) {
            existing.apply(activity)
        } else {
            modelContext.insert(RecentActivityRecord(activity))
        }

        try modelContext.save()
    }

    /// `#Predicate` cannot close over a property of a struct, so the raw value is lifted into a
    /// local first — the same shape `QuranProgressRepository` needs for its verse reference.
    private func record(for kind: ActivityKind) throws -> RecentActivityRecord? {
        let raw = kind.rawValue

        var descriptor = FetchDescriptor<RecentActivityRecord>(
            predicate: #Predicate { $0.kindRaw == raw }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
