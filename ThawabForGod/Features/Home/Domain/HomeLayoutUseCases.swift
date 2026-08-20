//
//  HomeLayoutUseCases.swift
//  ThawabForGod
//

import Foundation

/// The stored arrangement of Home.
nonisolated struct GetHomeLayoutUseCase: Sendable {
    private let repository: any HomeLayoutRepositoring

    init(repository: any HomeLayoutRepositoring) {
        self.repository = repository
    }

    func callAsFunction() -> HomeLayout {
        repository.layout()
    }
}

/// Persists an arrangement the customization screen has just edited.
///
/// A type rather than a call straight to the repository, and it earns it: the view model depends
/// on this rather than on `HomeLayoutRepositoring`, so the day a change to the layout also has to
/// invalidate something else — a widget timeline, say — there is one place to put it.
nonisolated struct UpdateHomeLayoutUseCase: Sendable {
    private let repository: any HomeLayoutRepositoring

    init(repository: any HomeLayoutRepositoring) {
        self.repository = repository
    }

    func callAsFunction(_ layout: HomeLayout) {
        repository.save(layout)
    }
}

/// Puts Home back to the arrangement it shipped with.
///
/// Returns the resulting layout rather than leaving the caller to re-read it: the screen needs a
/// value to redraw from immediately, and rounding back through the store to fetch what this call
/// just established would be a longer way to the same answer.
nonisolated struct ResetHomeLayoutUseCase: Sendable {
    private let repository: any HomeLayoutRepositoring

    init(repository: any HomeLayoutRepositoring) {
        self.repository = repository
    }

    @discardableResult
    func callAsFunction() -> HomeLayout {
        repository.reset()
        return repository.layout()
    }
}
