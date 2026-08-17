//
//  TasbihProgressRepository.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData-backed tasbih progress — the first user data the app writes outside bookmarks.
///
/// `@ModelActor` gives this actor its own `ModelContext` on its own executor, so a save happens
/// off the main actor and never touches the context SwiftUI uses. Only `TasbihSession` values
/// cross the boundary — never a `TasbihSessionModel`.
///
/// That isolation is what makes the view model's throttling safe to reason about: counting is
/// main-actor state that moves on every tap, saving is a hop to this actor that happens at lap
/// boundaries and on the way out, and the two never contend for the same object.
@ModelActor
actor TasbihProgressRepository: TasbihProgressRepositoring {

    func session(for dhikrID: TasbihDhikr.ID) throws -> TasbihSession? {
        try model(for: dhikrID)?.domainValue
    }

    /// Upsert. Updates the existing row in place when there is one, so the stored `id` survives
    /// a save and does not churn on every lap.
    func save(_ session: TasbihSession) throws {
        if let existing = try model(for: session.dhikrID) {
            existing.apply(session)
        } else {
            modelContext.insert(TasbihSessionModel(session))
        }
        try modelContext.save()
    }

    func reset(dhikrID: TasbihDhikr.ID) throws {
        guard let existing = try model(for: dhikrID) else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    private func model(for dhikrID: TasbihDhikr.ID) throws -> TasbihSessionModel? {
        var descriptor = FetchDescriptor<TasbihSessionModel>(
            predicate: #Predicate { $0.dhikrID == dhikrID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
