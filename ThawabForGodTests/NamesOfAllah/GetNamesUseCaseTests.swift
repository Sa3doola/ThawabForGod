//
//  GetNamesUseCaseTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The use case adds one thing to the repository — the ordering guarantee — so that is what most
/// of this suite is about.
struct GetNamesUseCaseTests {

    @Test func namesComeStraightFromTheRepository() async throws {
        let expected = [DivineName.stub(id: 1), DivineName.stub(id: 2)]
        let useCase = GetNamesUseCase(repository: StubNamesRepository(.success(expected)))

        #expect(try await useCase.allNames(in: .english) == expected)
    }

    /// A repository that returns rows in whatever order the store felt like must not reach a
    /// screen that way. This is the reason the sort exists in Swift as well as in the SQL.
    @Test func namesAreOrderedEvenWhenTheRepositoryIsNot() async throws {
        let shuffled = [
            DivineName.stub(id: 42),
            DivineName.stub(id: 7),
            DivineName.stub(id: 99),
            DivineName.stub(id: 1)
        ]
        let useCase = GetNamesUseCase(repository: StubNamesRepository(.success(shuffled)))

        #expect(try await useCase.allNames(in: .english).map(\.order) == [1, 7, 42, 99])
    }

    @Test func theLanguageIsForwardedAsGiven() async throws {
        let repository = StubNamesRepository()
        let useCase = GetNamesUseCase(repository: repository)

        _ = try await useCase.allNames(in: .arabic)

        #expect(await repository.requestedLanguages == [.arabic])
    }

    @Test func anEmptyListStaysEmptyRatherThanFailing() async throws {
        let useCase = GetNamesUseCase(repository: StubNamesRepository(.success([])))

        #expect(try await useCase.allNames(in: .english).isEmpty)
    }

    @Test func aFailureIsPropagatedRatherThanSwallowed() async {
        let useCase = GetNamesUseCase(repository: StubNamesRepository(.failure(NamesStubError())))

        await #expect(throws: NamesStubError.self) {
            try await useCase.allNames(in: .english)
        }
    }
}

/// The corpus row becomes a `DivineName`.
///
/// Built from a hand-made record — the row-to-record half is covered end to end by
/// `NamesRepositoryTests` against the real bundle, and reaching a GRDB `Row` directly would mean
/// linking GRDB into the test target for no gain.
struct DivineNameMappingTests {

    private let record = DivineNameRecord(
        id: 3,
        arabic: "الْمَلِكُ",
        transliteration: "Al Malik",
        meaningEnglish: "The King / Eternal Lord",
        explanationEnglish: "He who owns everything.",
        reference: "(20:114)(23:116)"
    )

    @Test func anEnglishReaderGetsEveryColumn() {
        let name = record.domainValue(in: .english)

        #expect(name.id == 3)
        #expect(name.order == 3)
        #expect(name.arabic == "الْمَلِكُ")
        #expect(name.transliteration == "Al Malik")
        #expect(name.meaning == "The King / Eternal Lord")
        #expect(name.explanation == "He who owns everything.")
        #expect(name.reference == "(20:114)(23:116)")
    }

    /// The corpus has no Arabic glosses, so an Arabic reader gets the name and the citation and
    /// nothing invented in between.
    @Test func anArabicReaderGetsTheNameAndTheCitationOnly() {
        let name = record.domainValue(in: .arabic)

        #expect(name.arabic == "الْمَلِكُ")
        #expect(name.transliteration == nil)
        #expect(name.meaning == nil)
        #expect(name.explanation == nil)
        #expect(name.reference == "(20:114)(23:116)", "verse numbers read the same in both")
    }

    @Test func absentColumnsStayAbsent() {
        let record = DivineNameRecord(
            id: 9,
            arabic: "…",
            transliteration: "…",
            meaningEnglish: "…",
            explanationEnglish: nil,
            reference: nil
        )

        let name = record.domainValue(in: .english)
        #expect(name.explanation == nil)
        #expect(name.reference == nil)
    }
}
