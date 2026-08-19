//
//  AdhkarCoordinator.swift
//  ThawabForGod
//

import Observation

/// Owns which category the reader has open, and nothing else.
///
/// No `NavigationPath` here, deliberately — the adhkar tab's own `NavigationStack` is put up
/// once by `MainTabView`, and a second path would mean a `NavigationStack` nested inside that
/// one, which breaks the back gesture and the toolbar both. What this holds is the one piece of
/// state that decides whether the reading screen is on top: the list drives it through
/// `navigationDestination(item:)`, so a push and a back swipe are the same value changing.
///
/// The same division as `QiblaCoordinator`: the coordinator knows which screen, the view model
/// knows what is on it.
@Observable
@MainActor
final class AdhkarCoordinator {

    /// The category being read, or `nil` at the list.
    private(set) var openCategory: AdhkarCategory?

    func open(_ category: AdhkarCategory) {
        openCategory = category
    }

    func closeCategory() {
        openCategory = nil
    }
}
