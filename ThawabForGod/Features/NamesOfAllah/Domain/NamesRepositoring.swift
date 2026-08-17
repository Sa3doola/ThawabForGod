//
//  NamesRepositoring.swift
//  ThawabForGod
//

import Foundation

/// Reads the ninety-nine names. The feature depends on this, never on GRDB or SQL.
///
/// Read-only throughout — there is no counter, no progress and nothing of the user's here, which
/// is what makes this the simplest of the three content features and why it touches SwiftData not
/// at all.
///
/// `async` and language-parameterised for the same reasons as `AdhkarRepositoring`: the read
/// touches a database and must not land on a frame, and the language can change while the app is
/// running.
nonisolated protocol NamesRepositoring: Sendable {

    /// All ninety-nine, in canonical order.
    func allNames(in language: AppLanguage) async throws -> [DivineName]
}
