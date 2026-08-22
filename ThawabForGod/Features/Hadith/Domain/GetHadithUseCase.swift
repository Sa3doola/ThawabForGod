//
//  GetHadithUseCase.swift
//  ThawabForGod
//

import Foundation

/// What the hadith screens ask for: the collections, their divisions, and the narrations.
///
/// A thin composition over the repository, and thin on purpose — the same shape as
/// `GetQuranUseCase`. It exists so the view model depends on the feature's own vocabulary rather
/// than on a storage protocol, which is what lets a later slice land here without a screen
/// noticing: a bookmark marked on a narration, a search folded into the collection list.
nonisolated struct GetHadithUseCase: Sendable {
    private let repository: any HadithRepositoring

    init(repository: any HadithRepositoring) {
        self.repository = repository
    }

    func collections() async throws -> [HadithCollection] {
        try await repository.collections()
    }

    func books(inCollection collectionID: String) async throws -> [HadithBook] {
        try await repository.books(inCollection: collectionID)
    }

    func book(_ reference: BookReference) async throws -> HadithBook? {
        try await repository.book(reference)
    }

    func hadiths(inBook reference: BookReference) async throws -> [Hadith] {
        try await repository.hadiths(inBook: reference)
    }

    /// What a query matches, capped at `limit` narrations.
    ///
    /// The cap is the use case's to choose rather than the screen's: it exists because a narration
    /// row is expensive to draw and a common word matches thousands, not because of anything the
    /// list knows. A caller that wants a different one says so.
    ///
    /// Lower than the Quran's hundred. These rows are paragraphs of isnad and matn rather than
    /// single verses, and a reader who has to scroll past fifty of them has not been helped by
    /// the fifty-first.
    func search(_ query: ArabicSearchQuery, limit: Int = 50) async throws -> HadithSearchResults {
        guard !query.isEmpty else { return .none }
        return try await repository.search(query, limit: limit)
    }
}
