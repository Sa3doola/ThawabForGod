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
    private(set) var requestedIDs: [String] = []

    init(
        categories: Result<[AdhkarCategory], AdhkarStubError> = .success([.stub()]),
        adhkar: Result<[Dhikr], AdhkarStubError> = .success([])
    ) {
        self.categoriesResult = categories
        self.adhkarResult = adhkar
    }

    func categories() throws -> [AdhkarCategory] {
        try categoriesResult.get()
    }

    func category(id: String) throws -> AdhkarCategory? {
        requestedIDs.append(id)
        return try categoriesResult.get().first { $0.id == id }
    }

    func adhkar(in category: AdhkarCategory) throws -> [Dhikr] {
        requestedCategories.append(category)
        return try adhkarResult.get()
    }
}

nonisolated extension AdhkarCategory {

    /// A chapter with everything filled in, so a test only names the field it cares about.
    static func stub(
        id: String = "morning-evening",
        titleArabic: String = "أذكار الصباح والمساء",
        titleEnglish: String = "Morning & evening",
        group: AdhkarGroup = .daily,
        sortOrder: Int = 1,
        dhikrCount: Int = 24
    ) -> AdhkarCategory {
        AdhkarCategory(
            id: id,
            titleArabic: titleArabic,
            titleEnglish: titleEnglish,
            group: group,
            sortOrder: sortOrder,
            dhikrCount: dhikrCount
        )
    }
}

nonisolated extension Dhikr {

    static func stub(
        id: Int = 1,
        arabicText: String = "سُبْحَانَ اللَّهِ",
        repeatCount: Int = 3
    ) -> Dhikr {
        Dhikr(id: id, arabicText: arabicText, repeatCount: repeatCount)
    }
}
