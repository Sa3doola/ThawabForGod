//
//  NamesViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives the names grid and its detail screen.
///
/// The simplest of the three content view models: everything it holds comes out of a read-only
/// table, nothing is written back, and the only state that is not the corpus is the search field.
@Observable
@MainActor
final class NamesViewModel {

    /// What the grid has to show.
    enum Phase: Equatable {
        case loading
        case ready([DivineName])
        /// The corpus could not be read — a packaging fault, not something the user did.
        case unavailable
    }

    // MARK: State

    private(set) var phase: Phase = .loading

    /// What has been typed into the search field.
    ///
    /// Settable from the view, unlike the rest of this type's state, because a `TextField` needs
    /// a two-way binding and routing every keystroke through a method would buy nothing.
    var query = "" {
        didSet {
            // Only recompute when the text actually changed. SwiftUI can write an identical value
            // back through a binding, and filtering 99 names on every one of those is waste.
            if query != oldValue { filter() }
        }
    }

    /// The names that match `query`, in canonical order.
    ///
    /// Stored rather than computed so the filter runs once per keystroke instead of once per
    /// redraw — and so the grid, which reads it many times while laying out, is not re-filtering
    /// under each cell.
    private(set) var matches: [DivineName] = []

    @ObservationIgnored private let useCase: GetNamesUseCase
    @ObservationIgnored private let tips: any NamesTipReporting

    init(useCase: GetNamesUseCase, tips: any NamesTipReporting = NamesTipReporter()) {
        self.useCase = useCase
        self.tips = tips
    }

    // MARK: Derived

    /// Whether a search is narrowing the list. Drives the "nothing found" state, which must not
    /// appear merely because the corpus has not loaded yet.
    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Every name, regardless of the search. What the detail screen pages through.
    var allNames: [DivineName] {
        guard case .ready(let names) = phase else { return [] }
        return names
    }

    // MARK: Loading

    /// Loads the names for a language.
    ///
    /// Driven from the grid's `.task(id:)`, so a language change re-runs it and SwiftUI owns the
    /// lifetime — there is no stored `Task` here and nothing to cancel by hand.
    func load(in language: AppLanguage) async {
        phase = .loading

        do {
            let names = try await useCase.allNames(in: language)
            guard !Task.isCancelled else { return }
            phase = .ready(names)
        } catch {
            guard !Task.isCancelled else { return }
            phase = .unavailable
        }

        filter()
        await tips.namesOpened()
    }

    // MARK: Searching

    /// Narrows the list to what matches the query.
    ///
    /// In memory and over the already-loaded rows: 99 names is small enough that a round trip to
    /// SQLite per keystroke would cost more than it saved, and it keeps the search working
    /// identically for a view model built on a stub.
    ///
    /// Matching is diacritic- and case-insensitive on purpose. Arabic here is fully vowelled and
    /// nobody types the harakat, so a literal `contains` would find الرحمن only for someone who
    /// typed الرَّحْمَنُ exactly. `.diacriticInsensitive` is what makes the obvious search work.
    private func filter() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        guard case .ready(let names) = phase else {
            matches = []
            return
        }

        guard !trimmed.isEmpty else {
            matches = names
            return
        }

        matches = names.filter { name in
            [name.arabic, name.transliteration, name.meaning]
                .compactMap { $0 }
                .contains { $0.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    /// Clears the search. Separate from writing `query` directly so the view's clear button and a
    /// future "cancel" both go through one path.
    func clearSearch() {
        query = ""
    }

    // MARK: Detail

    /// Reports that a name was opened, which retires the tip that pointed at it.
    func nameOpened() {
        tips.nameOpened()
    }
}
