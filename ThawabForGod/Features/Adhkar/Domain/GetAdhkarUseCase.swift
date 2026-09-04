//
//  GetAdhkarUseCase.swift
//  ThawabForGod
//

import Foundation

/// What the adhkar screens ask for: the chapters, one chapter by name, and what is inside one.
///
/// A thin composition over the repository, and thin on purpose. It exists so the view model
/// depends on the feature's own vocabulary rather than on a storage protocol, which is what lets
/// a later slice — filtering out what has already been read today, say, or folding in a
/// bookmark — land here without any screen noticing.
nonisolated struct GetAdhkarUseCase: Sendable {
    private let repository: any AdhkarRepositoring

    init(repository: any AdhkarRepositoring) {
        self.repository = repository
    }

    func categories() async throws -> [AdhkarCategory] {
        try await repository.categories()
    }

    func category(id: String) async throws -> AdhkarCategory? {
        try await repository.category(id: id)
    }

    func adhkar(in category: AdhkarCategory) async throws -> [Dhikr] {
        try await repository.adhkar(in: category)
    }
}
