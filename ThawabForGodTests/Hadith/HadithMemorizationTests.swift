//
//  HadithMemorizationTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The real SwiftData store, in memory — schedules and the due queue.
@MainActor
struct HadithMemorizationRepositoryTests {

    private func makeRepository() throws -> HadithMemorizationRepository {
        let persistence = try PersistenceController(inMemory: true)
        return HadithMemorizationRepository(modelContainer: persistence.container)
    }

    private let today = Date(timeIntervalSince1970: 1_750_000_000)
    private let first = HadithID(collection: "bukhari", number: 1)
    private let second = HadithID(collection: "muslim", number: 8)

    private func memorization(
        _ id: HadithID,
        dueOn: Date,
        repetition: Int = 0
    ) -> HadithMemorization {
        HadithMemorization(
            id: id,
            bookNumber: 1,
            state: MemorizationState(
                easiness: 2.5,
                repetition: repetition,
                intervalInDays: 1,
                dueOn: dueOn,
                lastReviewedOn: nil
            )
        )
    }

    @Test func theDeckStartsEmpty() async throws {
        #expect(try await makeRepository().all().isEmpty)
    }

    @Test func anAddedNarrationIsInTheDeck() async throws {
        let repository = try makeRepository()

        try await repository.add(memorization(first, dueOn: today))

        #expect(try await repository.all().map(\.id) == [first])
    }

    /// **Adding something already in the deck must not reset it.** A reader three weeks into a
    /// narration would otherwise lose all of it to one stray tap.
    @Test func addingSomethingAlreadyInTheDeckLeavesItAlone() async throws {
        let repository = try makeRepository()

        try await repository.add(memorization(first, dueOn: today, repetition: 5))
        try await repository.add(memorization(first, dueOn: today, repetition: 0))

        let deck = try await repository.all()
        #expect(deck.count == 1)
        #expect(deck.first?.state.repetition == 5)
    }

    @Test func removingTakesItOutOfTheDeck() async throws {
        let repository = try makeRepository()

        try await repository.add(memorization(first, dueOn: today))
        try await repository.remove(first)

        #expect(try await repository.all().isEmpty)
    }

    @Test func answeringWritesTheNewSchedule() async throws {
        let repository = try makeRepository()

        try await repository.add(memorization(first, dueOn: today))
        try await repository.update(memorization(first, dueOn: today, repetition: 3))

        #expect(try await repository.all().first?.state.repetition == 3)
    }

    /// Answering a card the reader stopped memorizing while it was still on screen. Not an error,
    /// and not a row resurrected either.
    @Test func answeringSomethingNoLongerInTheDeckIsHarmless() async throws {
        let repository = try makeRepository()

        try await repository.update(memorization(first, dueOn: today, repetition: 3))

        #expect(try await repository.all().isEmpty)
    }

    // MARK: The queue

    @Test func onlyWhatIsDueIsInTheQueue() async throws {
        let repository = try makeRepository()

        try await repository.add(memorization(first, dueOn: today))
        try await repository.add(
            memorization(second, dueOn: today.addingTimeInterval(7 * 86_400))
        )

        #expect(try await repository.due(on: today).map(\.id) == [first])
    }

    /// An item missed on Tuesday is still due on Thursday — the queue asks for everything due on
    /// *or before* the date, so nothing skipped is silently dropped.
    @Test func somethingOverdueIsStillInTheQueue() async throws {
        let repository = try makeRepository()

        try await repository.add(
            memorization(first, dueOn: today.addingTimeInterval(-30 * 86_400))
        )

        #expect(try await repository.due(on: today).count == 1)
    }

    /// Longest-overdue first, so the narration the reader has neglected most is the one asked.
    @Test func theQueueIsSoonestDueFirst() async throws {
        let repository = try makeRepository()

        try await repository.add(memorization(first, dueOn: today))
        try await repository.add(
            memorization(second, dueOn: today.addingTimeInterval(-86_400))
        )

        #expect(try await repository.due(on: today).map(\.id) == [second, first])
    }
}

/// The review session: what is due, what answering does, and what starting and stopping mean.
@MainActor
struct MemorizeHadithUseCaseTests {

    private let today = Date(timeIntervalSince1970: 1_750_000_000)
    private let hadith = Hadith.stub(number: 1, text: "الأول")
    private let other = Hadith.stub(collectionID: "muslim", bookNumber: 3, number: 8, text: "الثاني")

    private func makeUseCase(
        deck: [HadithMemorization] = [],
        corpus: [Hadith]? = nil
    ) -> (MemorizeHadithUseCase, StubHadithMemorizationRepository) {
        let store = StubHadithMemorizationRepository(deck: deck)
        let useCase = MemorizeHadithUseCase(
            memorization: store,
            corpus: StubHadithRepository(hadiths: .success(corpus ?? [hadith, other])),
            scheduler: SpacedRepetitionScheduler(timeZone: TimeZone(identifier: "UTC")!)
        )
        return (useCase, store)
    }

    @Test func anEmptyDeckReadsNothingFromTheCorpus() async throws {
        let corpus = StubHadithRepository()
        let useCase = MemorizeHadithUseCase(
            memorization: StubHadithMemorizationRepository(),
            corpus: corpus
        )

        #expect(try await useCase.deck().isEmpty)
        #expect(corpus.requests.isEmpty)
    }

    /// Starting puts the narration in the deck due immediately — the one moment the reader
    /// certainly wants to see it is the one they chose it in.
    @Test func startingMakesItDueNow() async throws {
        let (useCase, store) = makeUseCase()

        try await useCase.start(hadith, on: today)

        let card = try #require(store.deck.first)
        #expect(card.id == hadith.id)
        #expect(card.state.isDue(on: today))
        #expect(card.state.isNew)
    }

    @Test func stoppingForgetsTheSchedule() async throws {
        let (useCase, store) = makeUseCase()

        try await useCase.start(hadith, on: today)
        try await useCase.stop(hadith.id)

        #expect(store.deck.isEmpty)
    }

    @Test func togglingAddsThenRemoves() async throws {
        let (useCase, store) = makeUseCase()

        try await useCase.toggle(hadith, on: today)
        #expect(store.deck.count == 1)

        try await useCase.toggle(hadith, on: today)
        #expect(store.deck.isEmpty)
    }

    /// Cards arrive joined to their narrations, so one cannot be drawn with another's text.
    @Test func aCardCarriesItsNarration() async throws {
        let (useCase, _) = makeUseCase()
        try await useCase.start(hadith, on: today)

        let cards = try await useCase.due(on: today)

        #expect(cards.count == 1)
        #expect(cards.first?.hadith.text == "الأول")
    }

    /// A schedule whose narration the corpus no longer has is dropped rather than shown as a card
    /// with nothing on it.
    @Test func aCardWhoseNarrationIsGoneIsDropped() async throws {
        let (useCase, _) = makeUseCase(corpus: [hadith])

        try await useCase.start(hadith, on: today)
        try await useCase.start(other, on: today)

        #expect(try await useCase.deck().map(\.id) == [hadith.id])
    }

    /// Counting is its own path, and it must not read the corpus — joining fifteen thousand
    /// characters of Arabic onto a number to display "1" is work done for nothing.
    @Test func countingDueCardsReadsNoNarrations() async throws {
        let corpus = StubHadithRepository()
        let store = StubHadithMemorizationRepository()
        let useCase = MemorizeHadithUseCase(memorization: store, corpus: corpus)

        try await useCase.start(hadith, on: today)

        #expect(try await useCase.dueCount(on: today) == 1)
        #expect(!corpus.requests.contains(.hadithsByID([hadith.id])))
    }

    /// Answering runs the scheduler and writes the result — the two happen together, which is the
    /// whole of what this use case adds over its two dependencies.
    @Test func answeringSchedulesTheCardAgain() async throws {
        let (useCase, store) = makeUseCase()
        try await useCase.start(hadith, on: today)
        let card = try #require(try await useCase.due(on: today).first)

        let state = try await useCase.answer(card, with: .good, on: today)

        #expect(state.repetition == 1)
        #expect(state.intervalInDays == 1)
        #expect(store.deck.first?.state.repetition == 1)
        #expect(try await useCase.dueCount(on: today) == 0)
    }

    @Test func failingACardBringsItBackTomorrow() async throws {
        let (useCase, _) = makeUseCase()
        try await useCase.start(hadith, on: today)
        let card = try #require(try await useCase.due(on: today).first)

        let state = try await useCase.answer(card, with: .again, on: today)

        #expect(state.repetition == 0)
        #expect(state.intervalInDays == 1)
    }
}

/// One review session: the queue, the reveal steps, and what an answer does to both.
@MainActor
struct HadithMemorizeViewModelTests {

    private let today = Date(timeIntervalSince1970: 1_750_000_000)
    private let first = Hadith.stub(number: 1, text: "الأول")
    private let second = Hadith.stub(collectionID: "muslim", bookNumber: 3, number: 8, text: "الثاني")

    private func makeViewModel(
        deck: [HadithMemorization] = [],
        corpus: [Hadith]? = nil,
        failing: Bool = false
    ) -> HadithMemorizeViewModel {
        HadithMemorizeViewModel(
            useCase: MemorizeHadithUseCase(
                memorization: StubHadithMemorizationRepository(
                    deck: deck,
                    failure: failing ? HadithStubError() : nil
                ),
                corpus: StubHadithRepository(hadiths: .success(corpus ?? [first, second])),
                scheduler: SpacedRepetitionScheduler(timeZone: TimeZone(identifier: "UTC")!)
            ),
            clock: TestClock(today)
        )
    }

    private func due(_ hadith: Hadith, on date: Date) -> HadithMemorization {
        HadithMemorization(hadith, state: .new(on: date))
    }

    /// Nothing in the deck and nothing due are different sentences, so the phase carries which —
    /// a reader who has never started needs telling how to, and one who is finished does not.
    @Test func anEmptyDeckSaysSo() async {
        let viewModel = makeViewModel()

        await viewModel.start()

        #expect(viewModel.phase == .done(deckIsEmpty: true))
    }

    @Test func aDeckWithNothingDueSaysSomethingElse() async {
        let scheduled = HadithMemorization(
            first,
            state: MemorizationState(
                easiness: 2.5,
                repetition: 1,
                intervalInDays: 6,
                dueOn: today.addingTimeInterval(6 * 86_400),
                lastReviewedOn: today
            )
        )
        let viewModel = makeViewModel(deck: [scheduled])

        await viewModel.start()

        #expect(viewModel.phase == .done(deckIsEmpty: false))
    }

    @Test func aSessionStartsHiddenOnTheFirstCard() async {
        let viewModel = makeViewModel(deck: [due(first, on: today)])

        await viewModel.start()

        #expect(viewModel.current?.id == first.id)
        #expect(viewModel.reveal == .hidden)
        #expect(viewModel.total == 1)
        #expect(viewModel.answered == 0)
    }

    /// **Grading is not offered until the narration is on screen.** Grading a card that is still
    /// face down is grading something other than recall.
    @Test func gradesAreOnlyOfferedOnceTheWholeNarrationShows() async {
        let viewModel = makeViewModel(deck: [due(first, on: today)])
        await viewModel.start()

        #expect(!viewModel.canGrade)

        viewModel.revealMore()
        #expect(viewModel.reveal == .opening)
        #expect(!viewModel.canGrade)

        viewModel.revealMore()
        #expect(viewModel.reveal == .full)
        #expect(viewModel.canGrade)
        #expect(!viewModel.canReveal)
    }

    @Test func revealingPastTheEndDoesNothing() async {
        let viewModel = makeViewModel(deck: [due(first, on: today)])
        await viewModel.start()

        for _ in 0..<5 { viewModel.revealMore() }

        #expect(viewModel.reveal == .full)
    }

    @Test func answeringMovesToTheNextCardFaceDown() async {
        let viewModel = makeViewModel(deck: [due(first, on: today), due(second, on: today)])
        await viewModel.start()
        viewModel.revealMore()
        viewModel.revealMore()

        await viewModel.answer(.good)

        #expect(viewModel.current?.id == second.id)
        #expect(viewModel.reveal == .hidden)
        #expect(viewModel.answered == 1)
        #expect(viewModel.total == 2)
    }

    /// A failed card leaves this session rather than being re-queued inside it. SM-2 has it back
    /// tomorrow, and re-asking it today would be the app inventing a rule the algorithm has not.
    @Test func aFailedCardStillLeavesTheSession() async {
        let viewModel = makeViewModel(deck: [due(first, on: today)])
        await viewModel.start()
        viewModel.revealMore()
        viewModel.revealMore()

        await viewModel.answer(.again)

        #expect(viewModel.phase == .done(deckIsEmpty: false))
    }

    /// An answer that did not land leaves the card up. Moving on would tell the reader it was
    /// recorded when it was not.
    @Test func anAnswerThatCannotBeWrittenIsNotSwallowed() async {
        let store = StubHadithMemorizationRepository(deck: [due(first, on: today)])
        let viewModel = HadithMemorizeViewModel(
            useCase: MemorizeHadithUseCase(
                memorization: FailingOnWriteRepository(inner: store),
                corpus: StubHadithRepository(hadiths: .success([first]))
            ),
            clock: TestClock(today)
        )

        await viewModel.start()
        await viewModel.answer(.good)

        #expect(viewModel.phase == .unavailable)
    }
}

/// Reads like the deck it wraps, and refuses every write. For the one case that needs the
/// difference — a session whose answer cannot be recorded.
nonisolated final class FailingOnWriteRepository: HadithMemorizationRepositoring, @unchecked Sendable {
    private let inner: StubHadithMemorizationRepository

    init(inner: StubHadithMemorizationRepository) {
        self.inner = inner
    }

    func all() async throws -> [HadithMemorization] { try await inner.all() }
    func due(on date: Date) async throws -> [HadithMemorization] { try await inner.due(on: date) }
    func add(_ memorization: HadithMemorization) async throws { throw HadithStubError() }
    func remove(_ id: HadithID) async throws { throw HadithStubError() }
    func update(_ memorization: HadithMemorization) async throws { throw HadithStubError() }
}
