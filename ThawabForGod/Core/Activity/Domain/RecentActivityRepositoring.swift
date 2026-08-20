//
//  RecentActivityRepositoring.swift
//  ThawabForGod
//

import Foundation

/// Where the user last got to, in each of the three things they can be in the middle of.
///
/// `record` is an **upsert on the kind**, not an insert. That is the whole contract: there is at
/// most one row per `ActivityKind`, so the store cannot grow with use and the section cannot fill
/// with duplicates. See `RecentActivity` for why the identity is the kind.
nonisolated protocol RecentActivityRepositoring: Sendable {
    /// Everything recorded, most recent first. At most one row per kind, so at most three rows.
    func recent() async throws -> [RecentActivity]

    /// Replaces this kind's row, or writes the first one.
    func record(_ activity: RecentActivity) async throws
}
