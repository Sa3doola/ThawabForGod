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
        let expected = [AdhkarCategory.stub(id: "sleep"), .stub(id: "waking")]
        let useCase = GetAdhkarUseCase(repository: StubAdhkarRepository(categories: .success(expected)))

        #expect(try await useCase.categories() == expected)
    }

    @Test func adhkarComeStraightFromTheRepository() async throws {
        let expected = [Dhikr.stub(id: 1), Dhikr.stub(id: 2)]
        let useCase = GetAdhkarUseCase(repository: StubAdhkarRepository(adhkar: .success(expected)))

        #expect(try await useCase.adhkar(in: .stub()) == expected)
    }

    /// The chapter is the whole interface. Passing a different one, or letting the repository
    /// pick, would show up nowhere else until a reader saw one chapter's adhkar under another's
    /// title.
    @Test func theChapterIsForwardedAsGiven() async throws {
        let repository = StubAdhkarRepository()
        let useCase = GetAdhkarUseCase(repository: repository)
        let category = AdhkarCategory.stub(id: "travel", group: .travel)

        _ = try await useCase.adhkar(in: category)

        #expect(await repository.requestedCategories == [category])
    }

    @Test func aChapterIsLookedUpByTheSlugItWasAskedFor() async throws {
        let repository = StubAdhkarRepository(categories: .success([.stub(id: "wind", group: .nature)]))
        let useCase = GetAdhkarUseCase(repository: repository)

        #expect(try await useCase.category(id: "wind")?.id == "wind")
        #expect(try await useCase.category(id: "thunder") == nil)
        #expect(await repository.requestedIDs == ["wind", "thunder"])
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
