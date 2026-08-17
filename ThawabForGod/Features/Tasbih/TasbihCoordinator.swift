//
//  TasbihCoordinator.swift
//  ThawabForGod
//

import Observation

/// Owns which preset the user has open, and nothing else.
///
/// No `NavigationPath`, for the same reason `AdhkarCoordinator` has none: Home owns the stack
/// these screens live in, and a second path would mean a `NavigationStack` nested inside the
/// first, which breaks the back gesture and the toolbar both. The preset list drives this through
/// `navigationDestination(item:)`, so a push and a back swipe are the same value changing.
@Observable
@MainActor
final class TasbihCoordinator {

    /// The preset being counted, or `nil` at the list.
    private(set) var openDhikr: TasbihDhikr?

    func open(_ dhikr: TasbihDhikr) {
        openDhikr = dhikr
    }

    func closeDhikr() {
        openDhikr = nil
    }
}
