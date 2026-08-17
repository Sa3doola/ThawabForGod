//
//  AdhkarDoubles.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// Something to fail with that is `Sendable`, unlike `any Error`.
nonisolated struct AdhkarStubError: Error, Equatable {}

/// A repository that returns what it was handed, and remembers what it was asked for.
///
/// An `actor` rather than a struct with a mutable box: it records calls, and the types under
/// test reach it from a nonisolated context. Its synchronous methods satisfy the protocol's
/// `async` requirements — that is what actor isolation means from the outside.
actor StubAdhkarRepository: AdhkarRepositoring {
    private let categoriesResult: Result<[AdhkarCategory], AdhkarStubError>
    private let adhkarResult: Result<[Dhikr], AdhkarStubError>

    private(set) var requestedCategories: [AdhkarCategory] = []
    private(set) var requestedLanguages: [AppLanguage] = []

    init(
        categories: Result<[AdhkarCategory], AdhkarStubError> = .success([.morning, .evening]),
        adhkar: Result<[Dhikr], AdhkarStubError> = .success([])
    ) {
        self.categoriesResult = categories
        self.adhkarResult = adhkar
    }

    func categories() throws -> [AdhkarCategory] {
        try categoriesResult.get()
    }

    func adhkar(in category: AdhkarCategory, language: AppLanguage) throws -> [Dhikr] {
        requestedCategories.append(category)
        requestedLanguages.append(language)
        return try adhkarResult.get()
    }
}

nonisolated extension Dhikr {

    /// A dhikr with everything filled in, so a test only names the field it cares about.
    static func stub(
        id: Int = 1,
        arabicText: String = "سُبْحَانَ اللَّهِ",
        translation: String? = "Glory is to Allah.",
        transliteration: String? = "Subḥāna-llāh.",
        reference: String = "Muslim 2692.",
        virtue: String? = nil,
        repeatCount: Int = 3
    ) -> Dhikr {
        Dhikr(
            id: id,
            arabicText: arabicText,
            translation: translation,
            transliteration: transliteration,
            reference: reference,
            virtue: virtue,
            repeatCount: repeatCount
        )
    }
}
