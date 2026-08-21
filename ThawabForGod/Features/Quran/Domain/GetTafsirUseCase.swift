//
//  GetTafsirUseCase.swift
//  ThawabForGod
//

import Foundation

/// What the tafsir sheet asks for: which commentaries there are, and what one of them says here.
///
/// Thin over the repository, the same shape as `GetQuranUseCase` — it exists so the view model
/// depends on the feature's vocabulary rather than on a storage protocol, and so the slice that
/// adds a second edition lands here rather than in a view.
nonisolated struct GetTafsirUseCase: Sendable {
    private let repository: any TafsirRepositoring

    init(repository: any TafsirRepositoring) {
        self.repository = repository
    }

    func editions() async throws -> [TafsirEdition] {
        try await repository.editions()
    }

    /// The note from a named edition, or from whichever the bundle lists first.
    ///
    /// The fallback is what lets the sheet ask before a preference exists — and what keeps a
    /// preference naming an edition that has since been removed from silently showing nothing.
    func note(
        for reference: VerseReference,
        in editionID: TafsirEdition.ID? = nil
    ) async throws -> TafsirNote? {
        let editions = try await repository.editions()

        guard let chosen = editions.first(where: { $0.id == editionID }) ?? editions.first else {
            return nil
        }

        return try await repository.note(for: reference, in: chosen.id)
    }
}
