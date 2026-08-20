//
//  HomeLayoutRepositoring.swift
//  ThawabForGod
//

import Foundation

/// Reads and writes how the user has arranged Home.
///
/// Nothing throws, for the reason `OnboardingRepositoring` gives: the store behind it is
/// key/value, a write cannot meaningfully fail, and inventing an error to catch would teach the
/// wrong lesson. A layout that cannot be read is not an error either — it is a user who has never
/// customized anything, and the answer is the default.
nonisolated protocol HomeLayoutRepositoring: Sendable {
    /// The stored arrangement, reconciled against today's enums, or the default if there is none.
    func layout() -> HomeLayout

    /// Persists an arrangement the user has just changed.
    func save(_ layout: HomeLayout)

    /// Forgets the arrangement entirely.
    ///
    /// Distinct from `save(.default)`, and the distinction is the project's standing rule about
    /// preferences: an unset key means "never opinionated", so a later change to what the default
    /// layout *is* reaches a user who reset, while a stored copy of today's default would freeze
    /// them at it forever.
    func reset()
}
