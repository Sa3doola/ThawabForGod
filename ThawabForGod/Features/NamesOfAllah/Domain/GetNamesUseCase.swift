//
//  GetNamesUseCase.swift
//  ThawabForGod
//

import Foundation

/// What the names screens ask for, and the one place the ordering guarantee is made good.
///
/// Thin over the repository, like `GetAdhkarUseCase` — it exists so the view model depends on the
/// feature's own vocabulary rather than on a storage protocol. The sort is the exception: the
/// repository asks SQLite for rows in order, and this makes sure of it in Swift as well, because
/// "the third name is third" is the one property every screen here quietly assumes.
nonisolated struct GetNamesUseCase: Sendable {
    private let repository: any NamesRepositoring

    init(repository: any NamesRepositoring) {
        self.repository = repository
    }

    /// All ninety-nine, ordered 1 to 99.
    ///
    /// Sorted here rather than trusted from below: an `ORDER BY` that someone drops in a later
    /// edit would otherwise show up as a subtly shuffled grid rather than as a failing test.
    func allNames(in language: AppLanguage) async throws -> [DivineName] {
        try await repository.allNames(in: language).sorted { $0.order < $1.order }
    }
}
