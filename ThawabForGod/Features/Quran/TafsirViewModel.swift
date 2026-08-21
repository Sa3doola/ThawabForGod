//
//  TafsirViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives the tafsir sheet: one verse, one commentary.
///
/// Its own type rather than more state on `QuranViewModel`, which already drives two screens and
/// holds the reader's bookmarks and position. This one owns a single question — what does the
/// commentary say about the verse in front of me — and nothing on the reading screen needs to
/// observe the answer.
@Observable
@MainActor
final class TafsirViewModel {

    /// What the sheet has to show.
    enum Phase: Equatable {
        case loading

        /// The commentary has something to say here.
        case note(TafsirNote)

        /// The commentary passes over this verse.
        ///
        /// Its own case, and the reason this enum is not `note(TafsirNote?)`: al-Jalalayn says
        /// nothing about 226 verses, and a reader who taps one is owed "the two Jalals wrote no
        /// note here" rather than a blank sheet that looks like a bug. Which edition was silent
        /// travels with it, because the answer is that edition's and not the app's.
        case silent(TafsirEdition)

        /// The commentary could not be read — a packaging fault, not something the reader did.
        case unavailable
    }

    private(set) var phase: Phase = .loading

    @ObservationIgnored private let useCase: GetTafsirUseCase

    init(useCase: GetTafsirUseCase) {
        self.useCase = useCase
    }

    /// Loads the note for one verse.
    ///
    /// Driven from the sheet's `.task(id:)`, so SwiftUI owns the lifetime and moving to another
    /// verse cancels the read that is already in flight.
    func load(_ reference: VerseReference) async {
        phase = .loading

        do {
            if let note = try await useCase.note(for: reference) {
                guard !Task.isCancelled else { return }
                phase = .note(note)
                return
            }

            // Nothing for this verse. Which edition was asked has to be recovered to say so by
            // name — the sheet cannot report silence without saying whose silence it is.
            let editions = try await useCase.editions()
            guard !Task.isCancelled else { return }
            phase = editions.first.map(Phase.silent) ?? .unavailable
        } catch {
            guard !Task.isCancelled else { return }
            phase = .unavailable
        }
    }
}
