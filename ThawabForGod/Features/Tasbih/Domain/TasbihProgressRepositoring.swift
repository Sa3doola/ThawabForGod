//
//  TasbihProgressRepositoring.swift
//  ThawabForGod
//

import Foundation

/// Where a user's counts live. The feature depends on this, never on SwiftData.
///
/// The other half of the storage split: `TasbihCatalogProviding` reads phrases nobody can change,
/// and this reads and writes the one thing in the feature that is the user's own. Both sit behind
/// protocols in the same Domain folder precisely so the view model cannot tell which is which.
///
/// `async` because the implementation is a `@ModelActor` running off the main actor, exactly as
/// `BookmarkRepository` is. Callers re-fetch after a write; there is no `@Query` behind a
/// repository.
nonisolated protocol TasbihProgressRepositoring: Sendable {

    /// The running session for a preset, or `nil` if it has never been counted.
    func session(for dhikrID: TasbihDhikr.ID) async throws -> TasbihSession?

    /// Stores a session, replacing whatever was there for the same `dhikrID`.
    ///
    /// An upsert rather than a separate insert and update: there is at most one session per
    /// dhikr, so making the caller find out which case it is in would be ceremony over a
    /// distinction that never matters to it.
    func save(_ session: TasbihSession) async throws

    /// Forgets a preset's progress entirely. A no-op when there is none.
    func reset(dhikrID: TasbihDhikr.ID) async throws
}
