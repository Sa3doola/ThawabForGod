//
//  NamesCoordinator.swift
//  ThawabForGod
//

import Observation

/// Owns which name the reader has open, and nothing else.
///
/// No `NavigationPath`, for the same reason `AdhkarCoordinator` and `TasbihCoordinator` have
/// none: the Home tab owns the stack these screens live in, and a second path would mean a
/// `NavigationStack` nested inside the first, which breaks the back gesture and the toolbar both.
/// The grid drives this through `navigationDestination(item:)`, so a push and a back swipe are the
/// same value changing.
@Observable
@MainActor
final class NamesCoordinator {

    /// The name being read, or `nil` at the grid.
    private(set) var openName: DivineName?

    func open(_ name: DivineName) {
        openName = name
    }

    func closeName() {
        openName = nil
    }
}
