//
//  TasbihSessionModel.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData's representation of a `TasbihSession`. Stays inside `Data`, exactly as
/// `BookmarkRecord` does: a `@Model` instance is bound to the context that fetched it and must
/// never cross an actor boundary — the domain value type is what travels.
///
/// `dhikrID` is unique because there is one running session per preset. The repository still
/// fetches before writing rather than leaning on the constraint to upsert for it: an explicit
/// read-then-update is what keeps the stored `id` and creation identity stable across a save,
/// and it fails loudly rather than silently replacing a row.
///
/// Every property carries a default. SwiftData needs one for lightweight migration to add this
/// model to a store that already exists — which every installed copy of the app has, since the
/// bookmarks schema shipped before this one did.
@Model
nonisolated final class TasbihSessionModel {
    var id: UUID = UUID()

    @Attribute(.unique) var dhikrID: String = ""

    var currentCount: Int = 0
    var targetCount: Int = 1
    var completedLaps: Int = 0
    var lastUpdated: Date = Date()

    init(
        id: UUID,
        dhikrID: String,
        currentCount: Int,
        targetCount: Int,
        completedLaps: Int,
        lastUpdated: Date
    ) {
        self.id = id
        self.dhikrID = dhikrID
        self.currentCount = currentCount
        self.targetCount = targetCount
        self.completedLaps = completedLaps
        self.lastUpdated = lastUpdated
    }

    convenience init(_ session: TasbihSession) {
        self.init(
            id: session.id,
            dhikrID: session.dhikrID,
            currentCount: session.currentCount,
            targetCount: session.targetCount,
            completedLaps: session.completedLaps,
            lastUpdated: session.lastUpdated
        )
    }

    var domainValue: TasbihSession {
        TasbihSession(
            id: id,
            dhikrID: dhikrID,
            currentCount: currentCount,
            targetCount: targetCount,
            completedLaps: completedLaps,
            lastUpdated: lastUpdated
        )
    }

    /// Updates everything except `id` and `dhikrID` — the row's identity and its key, neither of
    /// which a save is allowed to move.
    func apply(_ session: TasbihSession) {
        currentCount = session.currentCount
        targetCount = session.targetCount
        completedLaps = session.completedLaps
        lastUpdated = session.lastUpdated
    }
}
