//
//  GetAdhkarUseCaseTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The use case composes the repository and adds nothing of its own — so what is worth asserting
/// is exactly that: what goes in reaches the repository unchanged, and what comes back is not
/// quietly reshaped on the way out.
struct GetAdhkarUseCaseTests {

    @Test func categoriesComeStraightFromTheRepository() async throws {
        let useCase = GetAdhkarUseCase(
            repository: StubAdhkarRepository(categories: .success([.evening]))
        )

        #expect(try await useCase.categories() == [.evening])
    }

    @Test func adhkarComeStraightFromTheRepository() async throws {
        let expected = [Dhikr.stub(id: 1), Dhikr.stub(id: 2)]
        let useCase = GetAdhkarUseCase(
            repository: StubAdhkarRepository(adhkar: .success(expected))
        )

        #expect(try await useCase.adhkar(in: .morning, language: .english) == expected)
    }

    /// The two arguments are the whole interface. Swapping them, or dropping the language and
    /// letting the repository pick one, would show up nowhere else until a reader saw English
    /// text on an Arabic screen.
    @Test func theCategoryAndLanguageAreForwardedAsGiven() async throws {
        let repository = StubAdhkarRepository()
        let useCase = GetAdhkarUseCase(repository: repository)

        _ = try await useCase.adhkar(in: .evening, language: .arabic)

        #expect(await repository.requestedCategories == [.evening])
        #expect(await repository.requestedLanguages == [.arabic])
    }

    @Test func aFailureIsPropagatedRatherThanSwallowed() async {
        let useCase = GetAdhkarUseCase(
            repository: StubAdhkarRepository(categories: .failure(AdhkarStubError()))
        )

        await #expect(throws: AdhkarStubError.self) {
            try await useCase.categories()
        }
    }
}
