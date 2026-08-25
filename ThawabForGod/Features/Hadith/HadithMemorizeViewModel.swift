//
//  HadithMemorizeViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives one review session, and the deck it draws from.
///
/// Its own view model rather than more state on `HadithViewModel`, which already drives three
/// screens. A session is a different mode: it has a queue, a position in that queue, and a card
/// that is half-hidden — none of which means anything to the screens that read the corpus.
///
/// **The queue is taken once, at the start of the session.** Re-reading the store after every
/// answer would put a card the reader just failed straight back at the end of the same queue,
/// because a lapse is due again tomorrow and "tomorrow" is not "due on or before today" — but a
/// card answered `.easy` and one answered `.again` would come back in a different order each
/// reload, and a session that reshuffles under the reader is disorienting. So the session works
/// through the list it started with.
@Observable
@MainActor
final class HadithMemorizeViewModel {

    /// What the session screen has to show.
    nonisolated enum Phase: Equatable, Sendable {
        case loading
        /// Cards remain. The first of them is the one on screen.
        case reviewing([HadithReviewCard])
        /// Nothing is due. Either the deck is empty or the reader is done for today — which are
        /// different sentences, so the case carries which.
        case done(deckIsEmpty: Bool)
        case unavailable
    }

    /// How much of the narration the card is showing.
    ///
    /// **Progressive masking**, which the memorization plan asks for and which has to be adapted
    /// to what a hadith is. A narration opens with its chain of transmission and only then says
    /// what was said; hiding the whole thing and revealing the whole thing would make the isnad
    /// the first thing recalled, which is not what anyone memorizes. So the steps go from nothing
    /// shown, to an opening the reader can find their place by, to all of it.
    nonisolated enum Reveal: Int, CaseIterable, Comparable, Sendable {
        /// The citation only. What the reader is asked from.
        case hidden
        /// The opening words, as a prompt when the citation alone is not enough.
        case opening
        /// The whole narration.
        case full

        static func < (lhs: Reveal, rhs: Reveal) -> Bool { lhs.rawValue < rhs.rawValue }

        /// The next step, or `nil` at the end.
        var next: Reveal? { Reveal(rawValue: rawValue + 1) }
    }

    // MARK: State

    private(set) var phase: Phase = .loading

    /// How much of the current card is showing. Reset with every card.
    private(set) var reveal: Reveal = .hidden

    /// How many cards this session started with, so the screen can say "3 of 7".
    private(set) var total = 0

    /// How many have been answered.
    private(set) var answered = 0

    @ObservationIgnored private let useCase: MemorizeHadithUseCase
    @ObservationIgnored private let clock: any ClockService

    /// Used only to answer "and when would that bring it back?", never to write anything —
    /// the answer itself still goes through `useCase`, which owns the store.
    @ObservationIgnored private let scheduler = SpacedRepetitionScheduler()

    init(useCase: MemorizeHadithUseCase, clock: any ClockService) {
        self.useCase = useCase
        self.clock = clock
    }

    // MARK: Derived

    /// The card being asked, or `nil` when the session is over.
    var current: HadithReviewCard? {
        guard case .reviewing(let cards) = phase else { return nil }
        return cards.first
    }

    /// Whether there is more of the narration to show.
    var canReveal: Bool { reveal.next != nil }

    /// Whether the grade buttons should be offered.
    ///
    /// Only once the whole narration is on screen. Grading before seeing the answer is grading
    /// something other than recall.
    var canGrade: Bool { reveal == .full }

    // MARK: The session

    /// Starts a session over whatever is due now.
    func start() async {
        phase = .loading
        answered = 0
        reveal = .hidden

        do {
            let due = try await useCase.due(on: clock.now)
            total = due.count

            if due.isEmpty {
                phase = .done(deckIsEmpty: try await useCase.deck().isEmpty)
            } else {
                phase = .reviewing(due)
            }
        } catch {
            phase = .unavailable
        }
    }

    /// Shows the next step of the current card.
    func revealMore() {
        guard let next = reveal.next else { return }
        reveal = next
    }

    /// Records an answer and moves to the next card.
    ///
    /// How many days each answer would push the card out by — the line under each of the four
    /// buttons.
    ///
    /// **Computed rather than described**, because SM-2's intervals depend on the card's history:
    /// "good" is four days on a card seen twice and three weeks on one seen six times, and a
    /// button labelled with a fixed guess would be wrong for most of the deck. Running the
    /// scheduler is a handful of arithmetic on a value type — it writes nothing and touches no
    /// store, which is exactly what `Core/Memorization` was made pure for.
    ///
    /// `nil` when there is no card up, which is the only time the buttons are not on screen.
    func interval(after grade: ReviewGrade) -> Int? {
        guard let current else { return nil }

        return scheduler.next(current.memorization.state, grade: grade, on: clock.now)
            .intervalInDays
    }

    /// The card is dropped from the queue whatever the grade, including `.again`. SM-2 would have
    /// it back tomorrow rather than later today, and re-queueing it inside this session would be
    /// this app inventing a rule the algorithm does not have — a decision worth making
    /// deliberately later, not by accident now.
    func answer(_ grade: ReviewGrade) async {
        guard case .reviewing(let cards) = phase, let card = cards.first else { return }

        do {
            try await useCase.answer(card, with: grade, on: clock.now)
        } catch {
            // The answer did not land. Leaving the card up is the honest response: moving on
            // would tell the reader it was recorded when it was not.
            phase = .unavailable
            return
        }

        answered += 1
        reveal = .hidden

        let remaining = Array(cards.dropFirst())
        phase = remaining.isEmpty ? .done(deckIsEmpty: false) : .reviewing(remaining)
    }
}
